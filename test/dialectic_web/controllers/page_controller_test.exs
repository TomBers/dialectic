defmodule DialecticWeb.PageControllerTest do
  use DialecticWeb.ConnCase
  import Dialectic.GraphFixtures

  test "guests cannot generate grid tags", %{conn: conn} do
    graph = insert_graph(%{title: "Guest tag request"})

    conn = post(conn, ~p"/graphs/#{graph.title}/generate_tags")

    assert redirected_to(conn) == ~p"/users/log_in"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Sign in or create an account"
    assert Dialectic.Repo.reload!(graph).tags == graph.tags
  end

  test "signed-in viewers cannot generate tags for inaccessible or locked grids", %{conn: conn} do
    user = Dialectic.AccountsFixtures.user_fixture()

    for attrs <- [%{is_public: false}, %{is_locked: true}] do
      graph =
        insert_graph(
          Map.put(attrs, :title, "Restricted tags #{System.unique_integer([:positive])}")
        )

      response = conn |> log_in_user(user) |> post(~p"/graphs/#{graph.title}/generate_tags")
      assert response(response, 403)
      assert Dialectic.Repo.reload!(graph).tags == graph.tags
    end
  end

  test "retired reader routes return 404 while the current reader remains available", %{
    conn: conn
  } do
    graph = insert_graph(%{title: "Current Reader"})

    for view <- ["linear", "outline"] do
      response = get(conn, "/g/#{graph.slug}/#{view}?node_id=1")
      assert response.status == 404
      assert get_resp_header(response, "location") == []
    end

    assert conn |> get(~p"/g/#{graph.slug}?node=1") |> html_response(200) =~ "Current Reader"
  end

  test "guide describes the current workflow and links to the grid form", %{conn: conn} do
    document = conn |> get(~p"/intro/how") |> html_response(200) |> LazyHTML.from_document()

    assert document |> LazyHTML.query("#guide-hero h1") |> LazyHTML.text() =~
             "Get to know your AI workshop."

    for id <- ~w(guide-flow-step-ask guide-flow-step-share guide-shared-paths
                 guide-bookmark-nodes guide-save-highlights guide-live-editing
                 guide-grid-visibility guide-public-profile guide-explanation-level
                 guide-translate-node guide-search-grid guide-follow-thread
                 guide-create-synthesis guide-evidence-grounding guide-echo-chambers
                 guide-present-grid guide-export-grid guide-contribution-history
                 guide-follow-updates guide-focused-sharing guide-learning-plan) do
      refute Enum.empty?(LazyHTML.query(document, "##{id}"))
    end

    for id <- ~w(guide-start-grid-link guide-own-question-link) do
      assert document |> LazyHTML.query("##{id}") |> LazyHTML.attribute("href") ==
               ["/my/learning?new=true"]
    end

    assert Enum.empty?(LazyHTML.query(document, "a[href*='focus=grid']"))

    for {selector, text} <- [
          {"#guide-new-grid-privacy", "start private"},
          {"#guide-new-grid-privacy", "contributing requires signing in"},
          {"#guide-explanation-level", "beside Ask AI"},
          {"#guide-explanation-level", "descriptions inline"},
          {"#guide-learning-plan", "Add a learning plan"},
          {"#guide-learning-plan", "both Read and Grid"},
          {"#guide-critical-thinking-tools", "Show thinking tools"},
          {"#guide-critical-thinking-collaboration",
           "Philosophy for All and philosopher and educator Peter Worley"},
          {"#guide-critical-thinking-collaboration", "the final judgement remains yours"},
          {"#guide-bookmark-nodes", "Save for later"},
          {"#guide-save-highlights", "expand its saved passages inline"},
          {"#guide-export-grid", "More → Download"},
          {"#guide-contribution-history", "Grid history"},
          {"#guide-live-editing", "saved only in this browser"},
          {"#guide-grid-visibility", "Who can view and contribute"},
          {"#guide-follow-updates", "Account menu"},
          {"#guide-shared-paths", "Choose where the link starts"},
          {"#guide-evidence-grounding", "primary material and original research"}
        ] do
      assert document |> LazyHTML.query(selector) |> LazyHTML.text() =~ text
    end
  end

  test "AI exploration page balances benefits with common objections", %{conn: conn} do
    conn = get(conn, ~p"/intro/ai")

    html = html_response(conn, 200)

    assert html =~ ~s(id="ai-exploration-hero")
    assert html =~ "Use AI to open a question—not close it."
    assert html =~ "deserves your confidence"
    assert html =~ "basic or awkward to raise"
    assert html =~ ~s(id="ai-exploration-benefits")
    assert html =~ "Choose Simple, Expanded, or In-depth"
    assert html =~ ~s(id="ai-benefit-evidence")
    assert html =~ "primary sources, original research, official records"
    assert html =~ ~s(id="ai-exploration-chat-comparison")
    assert html =~ "Why not just use ChatGPT or Claude?"
    assert html =~ ~s(id="ai-chat-feature-table")
    assert html =~ ~s(id="ai-chat-assistants")
    assert html =~ ~s(id="ai-rationalgrid-branches")
    assert html =~ ~s(id="ai-chat-comparison-takeaway")
    assert html =~ "Get unstuck"
    assert html =~ "exact sticking point"
    assert html =~ "Explore connected paths"
    assert html =~ "Branch, compare, and synthesise ideas"
    assert html =~ "Check the evidence"
    assert html =~ "Keep and return"
    assert html =~ "Share and build together"
    assert html =~ "track contributions, and follow public work"
    assert html =~ ~s(id="ai-exploration-objections")
    assert html =~ ~s(id="ai-objection-wrong")
    assert html =~ ~s(id="ai-objection-passive")
    assert html =~ ~s(id="ai-objection-bias")
    assert html =~ "It can repeat an echo chamber."
    assert html =~ ~s(id="ai-objection-uncertainty")
    assert html =~ ~s(id="ai-objection-ownership")
    assert html =~ ~s(id="ai-objection-costs")
    assert html =~ ~s(id="ai-exploration-roles")
    assert html =~ ~s(id="ai-exploration-start-link")
  end
end
