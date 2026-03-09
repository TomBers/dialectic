defmodule DialecticWeb.LegacyRedirectControllerTest do
  use DialecticWeb.ConnCase

  import Dialectic.GraphFixtures

  describe "GET /:legacy_title (redirect_graph)" do
    test "301 redirects to /g/:slug when graph is found by title", %{conn: conn} do
      graph = insert_graph(%{title: "My Legacy Graph"})

      conn = get(conn, "/#{URI.encode("My Legacy Graph")}")

      assert conn.status == 301
      assert get_resp_header(conn, "location") == ["/g/#{graph.slug}"]
    end

    test "sets cache-control header on redirect", %{conn: conn} do
      insert_graph(%{title: "Cached Legacy Graph"})

      conn = get(conn, "/#{URI.encode("Cached Legacy Graph")}")

      assert get_resp_header(conn, "cache-control") |> List.first() =~ "public, max-age=86400"
    end

    test "returns 404 when graph is not found", %{conn: conn} do
      conn = get(conn, "/#{URI.encode("nonexistent-graph-title")}")

      assert conn.status == 404
    end

    test "preserves query string with token param on redirect", %{conn: conn} do
      graph = insert_graph(%{title: "Shared Legacy Graph"})

      conn = get(conn, "/#{URI.encode("Shared Legacy Graph")}?token=abc123")

      assert conn.status == 301
      assert get_resp_header(conn, "location") == ["/g/#{graph.slug}?token=abc123"]
    end

    test "preserves query string with multiple params on redirect", %{conn: conn} do
      graph = insert_graph(%{title: "Multi Param Graph"})

      conn = get(conn, "/#{URI.encode("Multi Param Graph")}?token=abc123&node=5")

      assert conn.status == 301
      assert get_resp_header(conn, "location") == ["/g/#{graph.slug}?token=abc123&node=5"]
    end

    test "redirects without query string when none is present", %{conn: conn} do
      graph = insert_graph(%{title: "No Params Graph"})

      conn = get(conn, "/#{URI.encode("No Params Graph")}")

      assert conn.status == 301
      assert get_resp_header(conn, "location") == ["/g/#{graph.slug}"]
    end

    test "handles URL-encoded titles with special characters", %{conn: conn} do
      graph = insert_graph(%{title: "Spaces & Special Characters!"})

      conn = get(conn, "/#{URI.encode("Spaces & Special Characters!")}")

      assert conn.status == 301
      assert get_resp_header(conn, "location") == ["/g/#{graph.slug}"]
    end
  end

  describe "GET /:legacy_title/linear (redirect_linear)" do
    test "301 redirects to /g/:slug/linear when graph is found by title", %{conn: conn} do
      graph = insert_graph(%{title: "Linear Legacy Graph"})

      conn = get(conn, "/#{URI.encode("Linear Legacy Graph")}/linear")

      assert conn.status == 301
      assert get_resp_header(conn, "location") == ["/g/#{graph.slug}/linear"]
    end

    test "returns 404 when graph is not found for linear view", %{conn: conn} do
      conn = get(conn, "/#{URI.encode("nonexistent-linear-graph")}/linear")

      assert conn.status == 404
    end

    test "preserves token query param on linear redirect", %{conn: conn} do
      graph = insert_graph(%{title: "Shared Linear Graph"})

      conn = get(conn, "/#{URI.encode("Shared Linear Graph")}/linear?token=xyz789")

      assert conn.status == 301
      assert get_resp_header(conn, "location") == ["/g/#{graph.slug}/linear?token=xyz789"]
    end

    test "preserves node and highlight params on linear redirect", %{conn: conn} do
      graph = insert_graph(%{title: "Deep Link Linear Graph"})

      conn = get(conn, "/#{URI.encode("Deep Link Linear Graph")}/linear?node_id=3&highlight=abc")

      assert conn.status == 301

      assert get_resp_header(conn, "location") == [
               "/g/#{graph.slug}/linear?node_id=3&highlight=abc"
             ]
    end
  end
end
