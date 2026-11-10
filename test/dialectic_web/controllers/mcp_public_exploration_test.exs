defmodule DialecticWeb.McpPublicExplorationTest do
  use DialecticWeb.ConnCase, async: false
  import Dialectic.AccountsFixtures
  import Dialectic.McpFixtures
  alias Dialectic.Integrations.{Exploration, OAuth}
  alias Dialectic.Repo

  setup :configure_mcp

  test "guided creation requires both permissions and reports aggregate progress", %{conn: conn} do
    user = user_fixture()
    params = %{request_id: Ecto.UUID.generate(), question: "Why are some explanations useful?"}
    path = ~p"/api/mcp/explorations/guided"
    assert conn |> post(path, params) |> json_response(401)

    create_conn =
      put_req_header(conn, "authorization", "Bearer " <> issue_token(user, "grids:create"))

    assert create_conn |> post(path, params) |> json_response(403)
    api = put_req_header(conn, "authorization", "Bearer " <> issue_token(user))
    result = api |> post(path, params) |> json_response(200)

    assert result["exploration"] == %{
             "stage" => "opening",
             "completed_steps" => 0,
             "total_steps" => 4,
             "error" => nil
           }

    assert result["grid"]["visibility"] == "private"
    assert Repo.aggregate(Exploration, :count) == 1
    assert api |> post(path, params) |> json_response(200) == result
    assert Repo.aggregate(Exploration, :count) == 1
    title = result["grid"]["title"]

    on_exit(fn ->
      case :global.whereis_name({:graph, title}) do
        pid when is_pid(pid) -> DynamicSupervisor.terminate_child(GraphSupervisor, pid)
        _ -> :ok
      end
    end)
  end

  test "clients can discover registration, register and renew a user-approved connection", %{
    conn: conn
  } do
    metadata = conn |> get(~p"/.well-known/oauth-authorization-server") |> json_response(200)
    assert metadata["registration_endpoint"] =~ "/oauth/register"
    assert "refresh_token" in metadata["grant_types_supported"]

    client =
      conn
      |> post(~p"/oauth/register", %{
        client_name: "A public MCP client",
        redirect_uris: ["https://client.example/callback"]
      })
      |> json_response(201)

    assert client["token_endpoint_auth_method"] == "none"
    {params, verifier} = authorization_params()

    params = %{
      params
      | "client_id" => client["client_id"],
        "redirect_uri" => "https://client.example/callback"
    }

    {:ok, request} = OAuth.validate_request(params)
    {:ok, code} = OAuth.authorize(user_fixture(), request)

    token =
      conn |> post(~p"/oauth/token", token_params(params, verifier, code)) |> json_response(200)

    rotated =
      conn
      |> post(~p"/oauth/token", %{
        grant_type: "refresh_token",
        refresh_token: token["refresh_token"],
        client_id: client["client_id"]
      })
      |> json_response(200)

    refute rotated["refresh_token"] == token["refresh_token"]
    assert {:ok, _} = OAuth.authenticate(rotated["access_token"], "grids:read")

    assert conn
           |> post(~p"/oauth/register", %{redirect_uris: ["http://remote.example/callback"]})
           |> json_response(400)
  end
end
