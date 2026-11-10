defmodule DialecticWeb.McpNavigationTest do
  use DialecticWeb.ConnCase, async: false

  import Dialectic.AccountsFixtures
  import Dialectic.McpFixtures

  alias Dialectic.Integrations.Authorization
  alias Dialectic.Repo

  setup :configure_mcp

  setup do
    previous = Application.fetch_env(:dialectic, :dev_routes)
    Application.put_env(:dialectic, :dev_routes, true)

    on_exit(fn ->
      case previous do
        {:ok, value} -> Application.put_env(:dialectic, :dev_routes, value)
        :error -> Application.delete_env(:dialectic, :dev_routes)
      end
    end)

    :ok
  end

  test "toolbar links signed-in developers to MCP authorization setup without granting access", %{
    conn: conn
  } do
    conn = log_in_user(conn, user_fixture())
    home = conn |> get(~p"/") |> html_response(200) |> LazyHTML.from_document()

    assert home |> LazyHTML.query("#mcp-testing-nav-link") |> LazyHTML.attribute("href") ==
             ["/users/connections#mcp-testing"]

    page = conn |> get(~p"/users/connections") |> html_response(200) |> LazyHTML.from_document()
    assert page |> LazyHTML.query("#mcp-testing") |> Enum.count() == 1

    inspector = LazyHTML.query(page, "#mcp-testing-open-inspector")
    assert LazyHTML.attribute(inspector, "href") == ["http://localhost:6274/"]
    assert LazyHTML.attribute(inspector, "target") == ["_blank"]
    assert LazyHTML.attribute(inspector, "rel") == ["noopener noreferrer"]

    settings = page |> LazyHTML.query("#mcp-testing-settings") |> LazyHTML.text()
    assert settings =~ "http://127.0.0.1:4001/mcp"
    assert settings =~ "grids:create grids:read grids:append"
    assert settings =~ "rationalgrid-mcp"
    assert Repo.aggregate(Authorization, :count) == 0
  end

  test "development toolbar link and setup are absent when development routes are disabled", %{
    conn: conn
  } do
    Application.put_env(:dialectic, :dev_routes, false)
    conn = log_in_user(conn, user_fixture())
    home = conn |> get(~p"/") |> html_response(200) |> LazyHTML.from_document()
    assert home |> LazyHTML.query("#mcp-testing-nav-link") |> Enum.count() == 0
    page = conn |> get(~p"/users/connections") |> html_response(200) |> LazyHTML.from_document()
    assert page |> LazyHTML.query("#mcp-testing") |> Enum.count() == 0
    assert page |> LazyHTML.query("#mcp-connections") |> Enum.count() == 1
    assert page |> LazyHTML.query("#mcp-connect") |> Enum.count() == 1

    assert page |> LazyHTML.query("#mcp-server-url") |> LazyHTML.attribute("value") == [
             "http://127.0.0.1:4001/mcp"
           ]
  end

  test "signed-out users cannot open connection management", %{conn: conn} do
    home = conn |> get(~p"/") |> html_response(200) |> LazyHTML.from_document()
    assert home |> LazyHTML.query("#mcp-testing-nav-link") |> Enum.count() == 0
    assert conn |> get(~p"/users/connections") |> redirected_to() == ~p"/users/log_in"
  end

  test "AI assistant feature is public and discoverable in production", %{conn: conn} do
    Application.put_env(:dialectic, :dev_routes, false)
    home = conn |> get(~p"/") |> html_response(200) |> LazyHTML.from_document()

    for id <- ["ai-assistants-nav-link", "home-ai-assistants-link"] do
      assert home |> LazyHTML.query("##{id}") |> LazyHTML.attribute("href") == [
               "/features/ai-assistants"
             ]
    end

    page =
      conn |> get(~p"/features/ai-assistants") |> html_response(200) |> LazyHTML.from_document()

    for id <- ~w(ai-assistants-setup ai-assistants-prompts ai-assistants-permissions) do
      assert page |> LazyHTML.query("##{id}") |> Enum.count() == 1
    end

    assert page |> LazyHTML.query("#feature-mcp-server-url") |> LazyHTML.attribute("value") == [
             "http://127.0.0.1:4001/mcp"
           ]

    [signup] = page |> LazyHTML.query("#ai-assistants-connect") |> LazyHTML.attribute("href")
    assert URI.parse(signup).path == "/users/register"
    assert URI.decode_query(URI.parse(signup).query)["return_to"] == "/users/connections"

    signed_in = log_in_user(conn, user_fixture())

    page =
      signed_in
      |> get(~p"/features/ai-assistants")
      |> html_response(200)
      |> LazyHTML.from_document()

    assert page |> LazyHTML.query("#ai-assistants-connect") |> LazyHTML.attribute("href") == [
             "/users/connections"
           ]

    assert page |> LazyHTML.query("#account-connections-link") |> LazyHTML.attribute("href") == [
             "/users/connections"
           ]
  end

  test "connection management lists and disconnects only the signed-in user's grants", %{
    conn: conn
  } do
    alias Dialectic.Integrations.OAuth
    user = user_fixture()
    other = user_fixture()
    own_token = issue_token(user)
    other_token = issue_token(other)
    [own] = OAuth.list_connections(user)
    [theirs] = OAuth.list_connections(other)
    signed_in = log_in_user(conn, user)

    page =
      signed_in |> get(~p"/users/connections") |> html_response(200) |> LazyHTML.from_document()

    assert page |> LazyHTML.query("#connection-#{own.id}") |> Enum.count() == 1
    assert page |> LazyHTML.query("#connection-#{theirs.id}") |> Enum.count() == 0
    assert page |> LazyHTML.query("#mcp-account-notice") |> LazyHTML.text() =~ user.email
    refute page |> LazyHTML.query("#mcp-account-notice") |> LazyHTML.text() =~ other.email

    assert page
           |> LazyHTML.query("#disconnect-connection-#{own.id}")
           |> LazyHTML.attribute("href") == ["/users/connections/#{own.id}"]

    assert signed_in |> delete(~p"/users/connections/#{theirs.id}") |> redirected_to() ==
             ~p"/users/connections"

    assert {:ok, _} = OAuth.authenticate(other_token, "grids:read")
    assert {:ok, _} = OAuth.authenticate(own_token, "grids:read")

    assert signed_in |> delete(~p"/users/connections/#{own.id}") |> redirected_to() ==
             ~p"/users/connections"

    assert {:error, :invalid_token} = OAuth.authenticate(own_token, "grids:read")
    assert {:ok, _} = OAuth.authenticate(other_token, "grids:read")
  end
end
