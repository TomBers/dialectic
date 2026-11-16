defmodule DialecticWeb.ThinkingToolsTest do
  use DialecticWeb.ConnCase, async: true

  test "public guide offers five closed goals with one starting tool each", %{conn: conn} do
    page =
      conn |> get(~p"/features/thinking-tools") |> html_response(200) |> LazyHTML.from_document()

    assert page |> LazyHTML.query("#thinking-tools-guide h1") |> Enum.count() == 1
    assert page |> LazyHTML.query("#thinking-goals > details") |> Enum.count() == 5
    assert page |> LazyHTML.query("#thinking-goals > details[open]") |> Enum.empty?()

    assert page |> LazyHTML.query("#thinking-tools-start") |> LazyHTML.attribute("href") ==
             ["/features/thinking-tools#explain"]

    for group <- DialecticWeb.ThinkingTools.groups() do
      assert page |> LazyHTML.query("details##{group.id} > summary h2") |> Enum.count() == 1

      assert page |> LazyHTML.query("details##{group.id}") |> LazyHTML.attribute("name") ==
               ["thinking-goal"]

      [starting_tool | other_tools] = group.tools

      assert page
             |> LazyHTML.query("##{group.id} #thinking-example-#{starting_tool.key}[open]")
             |> Enum.count() == 1

      for tool <- other_tools do
        assert page |> LazyHTML.query("#thinking-example-#{tool.key}[open]") |> Enum.empty?()
      end
    end

    for tool <- Dialectic.Integrations.ExplorationTools.catalog() do
      assert page |> LazyHTML.query("article##{tool.action} h3") |> Enum.count() == 1

      assert page |> LazyHTML.query("#thinking-example-#{tool.action} blockquote") |> Enum.count() ==
               1
    end

    assert page |> LazyHTML.query("#pros_cons") |> Enum.count() == 1
    assert page |> LazyHTML.query("#using-thinking-tools[open]") |> Enum.empty?()

    assert page |> LazyHTML.query("#thinking-tools-app-guide") |> LazyHTML.attribute("href") ==
             ["/intro/how#guide-critical-thinking-tools"]

    assert page |> LazyHTML.query("#thinking-tools-assistants") |> LazyHTML.attribute("href") ==
             ["/features/ai-assistants"]
  end

  test "editorial mentions link directly to the tool guide", %{conn: conn} do
    guide = conn |> get(~p"/intro/how") |> html_response(200) |> LazyHTML.from_document()

    for tool <-
          ~w(clarify assumptions says_who steel_man counterexample who_disagrees implications blind_spots what_if synthesis learning_plan) do
      assert guide |> LazyHTML.query("a[href='/features/thinking-tools##{tool}']") |> Enum.count() >=
               1
    end

    assert DialecticWeb.ThinkingTools.href("ideas") == "/features/thinking-tools#related_ideas"
    assert DialecticWeb.ThinkingTools.href("pro") == "/features/thinking-tools#thesis"
    assert DialecticWeb.ThinkingTools.href("con") == "/features/thinking-tools#antithesis"
  end
end
