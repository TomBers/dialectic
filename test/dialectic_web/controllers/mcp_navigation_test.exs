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

    for id <- ~w(ai-assistants-setup ai-assistants-prompts ai-assistants-permissions
                  ai-assistants-capabilities ai-assistants-thinking-tools ai-assistants-sharing
                  feature-connection-diagram feature-branch-diagram feature-publication
                  feature-exploration-modes feature-tool-directory) do
      assert page |> LazyHTML.query("##{id}") |> Enum.count() == 1
    end

    for group <- DialecticWeb.ThinkingTools.groups() do
      assert page
             |> LazyHTML.query("#mcp-thinking-goals-#{group.id}")
             |> LazyHTML.attribute("href") ==
               ["/features/thinking-tools##{group.id}"]
    end

    assert page |> LazyHTML.query("#feature-thinking-tools-guide") |> LazyHTML.attribute("href") ==
             ["/features/thinking-tools"]

    server_tools =
      ~r/registered\.set\("([^"]+)"/
      |> Regex.scan(File.read!(Path.expand("../../../mcp/src/server.ts", __DIR__)),
        capture: :all_but_first
      )
      |> List.flatten()
      |> Enum.sort()

    described_tools =
      page
      |> LazyHTML.query("#feature-tool-directory dl > div")
      |> LazyHTML.attribute("id")
      |> Enum.map(&String.replace_prefix(&1, "feature-tool-", ""))
      |> Enum.sort()

    assert described_tools == server_tools
    assert page |> LazyHTML.query("#feature-tool-directory") |> LazyHTML.attribute("open") == []

    assert page |> LazyHTML.query("#feature-setup-link") |> LazyHTML.attribute("href") == [
             "#ai-assistants-setup"
           ]

    assert page |> LazyHTML.query("#feature-highlights > li") |> Enum.count() == 3

    assert page |> LazyHTML.query("#ai-assistants-feature details[open]") |> Enum.empty?()

    assert page |> LazyHTML.query("meta[property='og:title']") |> LazyHTML.attribute("content") ==
             ["RationalGrid MCP — Explore ideas with your AI assistant"]

    assert page |> LazyHTML.query("meta[property='og:image']") |> LazyHTML.attribute("content") ==
             [DialecticWeb.Endpoint.url() <> "/images/rationalgrid-social.png"]

    assert page |> LazyHTML.query("#feature-mcp-server-url") |> LazyHTML.attribute("value") == [
             "https://rationalgrid.ai/mcp"
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

  test "assistant setup guides provide sourced steps and consistent public connection examples",
       %{conn: conn} do
    page =
      conn |> get(~p"/features/ai-assistants") |> html_response(200) |> LazyHTML.from_document()

    [server_url] =
      page |> LazyHTML.query("#feature-mcp-server-url") |> LazyHTML.attribute("value")

    assert URI.parse(server_url).scheme == "https"

    for {assistant, host} <- [
          {"chatgpt", "developers.openai.com"},
          {"claude", "support.claude.com"},
          {"gemini", "support.google.com"},
          {"perplexity", "www.perplexity.ai"},
          {"copilot", "code.visualstudio.com"},
          {"cursor", "cursor.com"},
          {"codex", "learn.chatgpt.com"},
          {"claude-code", "code.claude.com"}
        ] do
      guide = LazyHTML.query(page, "#feature-setup-#{assistant}")
      assert Enum.count(guide) == 1
      assert guide |> LazyHTML.query("summary") |> Enum.count() == 1
      assert guide |> LazyHTML.query("ol > li") |> Enum.count() >= 3
      assert guide |> LazyHTML.attribute("name") == ["mcp-assistant-setup"]

      [source] =
        page |> LazyHTML.query("#feature-setup-#{assistant}-source") |> LazyHTML.attribute("href")

      assert URI.parse(source).host == host
      assert URI.parse(source).scheme == "https"
    end

    cursor =
      page
      |> LazyHTML.query("#feature-setup-cursor pre code")
      |> LazyHTML.text()
      |> Jason.decode!()

    assert cursor == %{"mcpServers" => %{"rationalgrid" => %{"url" => server_url}}}

    assert page |> LazyHTML.query("#feature-setup-codex pre code") |> LazyHTML.text() =~
             server_url

    assert page |> LazyHTML.query("#feature-setup-claude-code pre code") |> LazyHTML.text() =~
             server_url

    assert page |> LazyHTML.query("#feature-setup-check") |> Enum.count() == 1
    assert page |> LazyHTML.query("#feature-gemini-eligibility") |> LazyHTML.text() =~ "US"
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
