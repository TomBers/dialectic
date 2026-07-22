defmodule DialecticWeb.CommunityLiveTest do
  use DialecticWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "community page" do
    test "mounts and filters by category and search", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/community")

      assert has_element?(view, "#community-search")
      assert has_element?(view, "#community-results-heading", "Find a useful starting point")

      render_patch(view, ~p"/community?category=deep_dives")
      assert has_element?(view, "#community-results-heading", "Deep dives")

      render_patch(view, ~p"/community?search=ethics")
      assert has_element?(view, "#community-results-heading", "Search results for \"ethics\"")
    end
  end
end
