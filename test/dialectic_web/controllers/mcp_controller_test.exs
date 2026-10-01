defmodule DialecticWeb.McpControllerTest do
  use DialecticWeb.ConnCase, async: false

  import Dialectic.AccountsFixtures
  import Dialectic.McpFixtures
  import Phoenix.LiveViewTest
  alias Dialectic.Integrations.{Authorization, ChatGrids, OAuth}
  alias Dialectic.Repo

  setup :configure_mcp

  test "authorization requires login and preserves its complete return URL", %{conn: conn} do
    {params, _verifier} = authorization_params()
    response = get(conn, ~p"/oauth/authorize", params)
    assert redirected_to(response) == ~p"/users/log_in"
    assert get_session(response, :user_return_to) =~ "/oauth/authorize?"
    assert get_session(response, :user_return_to) =~ "code_challenge="
    assert Repo.aggregate(Authorization, :count) == 0
  end

  test "explicit consent issues a code, token permits a private save, and disconnect revokes it",
       %{conn: conn} do
    user = user_fixture()
    signed_in = log_in_user(conn, user)
    {:ok, settings, _html} = live(signed_in, ~p"/users/settings")
    assert has_element?(settings, "#user-settings-connections[href='/users/connections']")
    {params, verifier} = authorization_params()
    response = get(signed_in, ~p"/oauth/authorize", params)
    document = response |> html_response(200) |> LazyHTML.from_document()
    assert LazyHTML.query(document, "#mcp-consent-form") |> Enum.count() == 1

    [consent] =
      document
      |> LazyHTML.query("input[name='authorization[consent]']")
      |> LazyHTML.attribute("value")

    assert Repo.aggregate(Authorization, :count) == 0

    allowed =
      post(signed_in, ~p"/oauth/authorize", %{
        "authorization" => %{"consent" => consent},
        "decision" => "allow"
      })

    callback = redirected_to(allowed) |> URI.parse()
    assert callback.host == "localhost"
    query = URI.decode_query(callback.query)
    assert query["state"] == "test-state"
    assert query["iss"] == DialecticWeb.Endpoint.url()

    token_response =
      conn
      |> post(~p"/oauth/token", token_params(params, verifier, query["code"]))
      |> json_response(200)

    token = token_response["access_token"]
    api = put_req_header(conn, "authorization", "Bearer " <> token)
    draft = grid_draft()
    saved = api |> post(~p"/api/mcp/grids", draft) |> json_response(200)
    assert saved["grid"]["visibility"] == "private"
    slug = saved["grid"]["id"]
    assert saved["node_count"] == 2
    assert api |> post(~p"/api/mcp/grids", draft) |> json_response(200) == saved
    assert conn |> get(~p"/api/public/grids/#{slug}") |> json_response(404)
    {:ok, view, _html} = live(signed_in, ~p"/g/#{slug}")
    assert has_element?(view, "#reading-node-1")
    assert has_element?(view, "#reading-node-2")

    first = api |> get(~p"/api/mcp/grids/#{slug}", limit: 1) |> json_response(200)
    assert first["next_offset"] == 1
    assert first["total_nodes"] == 2
    assert [%{"id" => "1"}] = first["nodes"]
    assert Map.keys(first["grid"]) |> Enum.sort() == ~w(id tags title url visibility)
    second = api |> get(~p"/api/mcp/grids/#{slug}", offset: 1) |> json_response(200)
    assert second["next_offset"] == nil

    [grant] = OAuth.list_connections(user)

    page =
      signed_in |> get(~p"/users/connections") |> html_response(200) |> LazyHTML.from_document()

    assert LazyHTML.query(page, "#connection-#{grant.id}") |> Enum.count() == 1

    assert signed_in |> delete(~p"/users/connections/#{grant.id}") |> redirected_to() ==
             ~p"/users/connections"

    assert api |> get(~p"/api/mcp/grids/#{slug}") |> json_response(401)
  end

  test "denial, tampered consent, wrong user and CSRF cannot grant access", %{conn: conn} do
    user = user_fixture()
    {params, _verifier} = authorization_params()
    consent = Phoenix.Token.sign(DialecticWeb.Endpoint, "mcp-consent", {user.id, params})
    body = %{"authorization" => %{"consent" => consent}, "decision" => "allow"}
    signed_in = log_in_user(conn, user)

    denied = post(signed_in, ~p"/oauth/authorize", %{body | "decision" => "deny"})
    query = denied |> redirected_to() |> URI.parse() |> Map.fetch!(:query) |> URI.decode_query()
    assert query["error"] == "access_denied"
    assert query["state"] == "test-state"
    assert query["iss"] == DialecticWeb.Endpoint.url()

    assert conn
           |> log_in_user(user_fixture())
           |> post(~p"/oauth/authorize", body)
           |> json_response(400)

    assert signed_in
           |> post(~p"/oauth/authorize", put_in(body, ["authorization", "consent"], "invalid"))
           |> json_response(400)

    assert_raise Plug.CSRFProtection.InvalidCSRFTokenError, fn ->
      signed_in
      |> put_private(:plug_skip_csrf_protection, false)
      |> post(~p"/oauth/authorize", body)
    end

    assert Repo.aggregate(Authorization, :count) == 0
  end

  test "API ignores browser login, enforces scopes and hides other users' grids", %{conn: conn} do
    user = user_fixture()
    {:ok, graph} = ChatGrids.create(user, grid_draft())

    assert conn
           |> log_in_user(user)
           |> post(~p"/api/mcp/grids", grid_draft())
           |> json_response(401)

    assert conn
           |> put_req_header("authorization", "Bearer invalid")
           |> post(~p"/api/mcp/grids", grid_draft())
           |> json_response(401)

    readonly = put_req_header(conn, "authorization", "Bearer " <> issue_token(user, "grids:read"))
    assert readonly |> post(~p"/api/mcp/grids", grid_draft()) |> json_response(403)
    other = put_req_header(conn, "authorization", "Bearer " <> issue_token(user_fixture()))
    assert other |> get(~p"/api/mcp/grids/#{graph.slug}") |> json_response(404)

    for params <- [%{limit: 51}, %{offset: -1}, %{limit: [1]}] do
      assert readonly |> get(~p"/api/mcp/grids/#{graph.slug}", params) |> json_response(400)
    end
  end

  test "methods are public templates for chat reasoning, not saved or generated analysis", %{
    conn: conn
  } do
    for method <-
          ~w(clarify assumptions counterexample implications blind_spots says_who who_disagrees steel_man what_if) do
      response = conn |> get(~p"/api/public/thinking-methods/#{method}") |> json_response(200)
      assert response["id"] == method
      assert response["prompt_template"] =~ "{{selected_idea}}"
      assert response["instructions"] =~ "not a completed analysis"
    end

    assert conn |> get(~p"/api/public/thinking-methods/unknown") |> json_response(404)
  end

  test "metadata advertises PKCE and the revocation endpoint invalidates tokens", %{conn: conn} do
    metadata = conn |> get(~p"/.well-known/oauth-authorization-server") |> json_response(200)
    assert metadata["code_challenge_methods_supported"] == ["S256"]
    assert metadata["token_endpoint_auth_methods_supported"] == ["none"]
    assert metadata["authorization_response_iss_parameter_supported"]
    token = issue_token(user_fixture())

    assert conn
           |> post(~p"/oauth/revoke", %{token: token, client_id: "test-client"})
           |> response(200) == ""

    assert {:error, :invalid_token} = OAuth.authenticate(token, "grids:create")
    assert conn |> post(~p"/oauth/revoke", %{token: token}) |> response(200) == ""
  end
end
