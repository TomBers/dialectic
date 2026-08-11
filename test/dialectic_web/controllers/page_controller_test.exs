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

    assert html =~ "Turn one question into a map of ideas you can examine and share."
    assert html =~ "critical thinking tools"
    assert html =~ "Step 2 · Read"
    assert html =~ "Step 4 · Examine"
    assert html =~ ~s(id="guide-examine-heading")
    assert html =~ ~s(id="guide-shared-paths")
    assert html =~ ~s(id="guide-star-nodes")
    assert html =~ ~s(id="guide-save-highlights")
    assert html =~ ~s(id="guide-live-editing")
    assert html =~ ~s(id="guide-grid-visibility")
    assert html =~ ~s(id="guide-public-profile")
    assert html =~ "Bookmarked ideas"
    assert html =~ "Save as a highlight"
    assert html =~ "Edit together by URL"
    assert html =~ ~s(id="guide-start-grid-link")
    assert html =~ ~s(href="/?focus=grid#start-here")
  end
end
