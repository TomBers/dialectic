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
end
