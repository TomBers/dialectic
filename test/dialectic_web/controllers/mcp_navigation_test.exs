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
    assert settings =~ "rationalgrid-chatgpt"
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
  end

  test "signed-out users cannot open connection management", %{conn: conn} do
    home = conn |> get(~p"/") |> html_response(200) |> LazyHTML.from_document()
    assert home |> LazyHTML.query("#mcp-testing-nav-link") |> Enum.count() == 0
    assert conn |> get(~p"/users/connections") |> redirected_to() == ~p"/users/log_in"
  end
end
