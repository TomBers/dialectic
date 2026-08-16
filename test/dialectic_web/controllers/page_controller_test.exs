defmodule DialecticWeb.PageControllerTest do
  use DialecticWeb.ConnCase
  import Dialectic.GraphFixtures

  test "legacy linear route redirects to the reader route", %{conn: conn} do
    graph = insert_graph(%{title: "Legacy Linear Redirect"})

    conn = get(conn, ~p"/g/#{graph.slug}/linear?node_id=3")

    assert redirected_to(conn) == ~p"/g/#{graph.slug}?node=3"
  end

  test "legacy outline route redirects to the reader route and preserves token", %{conn: conn} do
    graph = insert_graph(%{title: "Legacy Outline Redirect"})

    conn = get(conn, ~p"/g/#{graph.slug}/outline?node_id=2&token=abc123")

    assert redirected_to(conn) == ~p"/g/#{graph.slug}?node=2&token=abc123"
  end

  test "guide describes the current workflow and links to the grid form", %{conn: conn} do
    conn = get(conn, ~p"/intro/how")

    html = html_response(conn, 200)

    assert html =~ "Turn one question into a map of ideas you can explore and share."
    assert html =~ ~s(id="guide-hero")
    assert html =~ "when the first answer is not quite enough"
    assert html =~ "What makes a life feel meaningful?"
    assert html =~ ~s(id="guide-new-grid-privacy")
    assert html =~ "Step 2 · Read"
    assert html =~ "Step 4 · Examine"
    assert html =~ ~s(id="guide-critical-thinking-tools")
    assert html =~ ~s(id="guide-examine-heading")
    assert html =~ "Use the critical-thinking tools."
    assert html =~ ~s(id="guide-critical-thinking-collaboration")
    assert html =~ "More than a list of AI prompts."
    assert html =~ "Philosophy for All and philosopher and educator Peter Worley"
    assert html =~ "the final judgement remains yours"
    assert html =~ ~s(id="guide-flow-step-ask")
    assert html =~ ~s(id="guide-flow-step-share")
    assert html =~ ~s(id="guide-shared-paths")
    assert html =~ ~s(id="guide-bookmark-nodes")
    assert html =~ ~s(id="guide-save-highlights")
    assert html =~ ~s(id="guide-live-editing")
    assert html =~ ~s(id="guide-grid-visibility")
    assert html =~ ~s(id="guide-public-profile")
    assert html =~ ~s(id="guide-explanation-level")
    refute html =~ "Plain"
    assert html =~ "Standard"
    assert html =~ "Detailed"
    assert html =~ ~s(id="guide-translate-node")
    assert html =~ ~s(id="guide-search-grid")
    assert html =~ ~s(id="guide-group-grid")
    assert html =~ ~s(id="guide-create-synthesis")
    assert html =~ ~s(id="guide-evidence-grounding")
    assert html =~ "primary material and original research"
    assert html =~ ~s(id="guide-echo-chambers")
    assert html =~ ~s(id="guide-present-grid")
    assert html =~ ~s(id="guide-export-grid")
    assert html =~ ~s(id="guide-contribution-history")
    assert html =~ ~s(id="guide-follow-updates")
    assert html =~ ~s(id="guide-focused-sharing")
    assert html =~ "Bookmark an idea"
    assert html =~ "Save as a highlight"
    assert html =~ "Edit and talk together live"
    assert html =~ ~s(id="guide-start-grid-link")
    assert html =~ ~s(href="/?focus=grid#start-here")
  end

  test "AI exploration page balances benefits with common objections", %{conn: conn} do
    conn = get(conn, ~p"/intro/ai")

    html = html_response(conn, 200)

    assert html =~ ~s(id="ai-exploration-hero")
    assert html =~ "Use AI to open a question—not close it."
    assert html =~ "deserves your confidence"
    assert html =~ "basic or awkward to raise"
    assert html =~ ~s(id="ai-exploration-benefits")
    assert html =~ "Choose Standard, Detailed, or Expert"
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
