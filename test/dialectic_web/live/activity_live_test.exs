defmodule DialecticWeb.ActivityLiveTest do
  use DialecticWeb.ConnCase, async: false

  import Dialectic.AccountsFixtures
  import Phoenix.LiveViewTest

  alias Dialectic.Accounts
  alias Dialectic.Accounts.Graph
  alias Dialectic.DbActions.Graphs
  alias Dialectic.Follows
  alias Dialectic.GridActivity

  defp create_graph(owner, title, attrs \\ %{}) do
    title = "#{title}-#{System.unique_integer([:positive])}"
    {:ok, graph} = Graphs.create_new_graph(title, owner)

    graph
    |> Graph.changeset(Map.merge(%{tags: []}, attrs))
    |> Dialectic.Repo.update!()
  end

  defp named_user(username) do
    user = user_fixture()
    {:ok, user} = Accounts.update_user_profile(user, %{username: username})
    user
  end

  test "requires authentication", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/users/log_in"}}} = live(conn, ~p"/activity")
  end

  test "renders a twitter-like activity stream without topic follow controls", %{conn: conn} do
    viewer = named_user("stream-viewer")
    follower = named_user("stream-follower")
    followed_author = named_user("stream-author")
    graph_author = named_user("stream-graph-author")
    owned_graph = create_graph(viewer, "owned-stream-grid")
    followed_graph = create_graph(graph_author, "followed-stream-grid")

    assert {:ok, _follow} = Follows.follow_user(follower, viewer)
    assert {:ok, _follow} = Follows.follow_graph(follower, owned_graph)
    assert {:ok, _follow} = Follows.follow_graph(viewer, followed_graph)
    assert {:ok, _follow} = Follows.follow_user(viewer, followed_author)
    followed_user_graph = create_graph(followed_author, "new-grid-from-followed-user")

    {:ok, owned_log} =
      GridActivity.record_node_comment_created(owned_graph.title, follower, %{
        id: "2",
        class: "user",
        content: "## Owned grid note\n\nUseful detail.",
        parents: []
      })

    {:ok, followed_graph_log} =
      GridActivity.record_node_comment_created(followed_graph.title, graph_author, %{
        id: "3",
        class: "user",
        content: "## Followed grid note\n\nGrid detail.",
        parents: []
      })

    {:ok, lv, html} =
      conn
      |> log_in_user(viewer)
      |> live(~p"/activity")

    refute has_element?(lv, "#activity-topic-follow-form")
    assert html =~ ~s(href="/activity")
    assert has_element?(lv, "#activity-summary")
    assert has_element?(lv, "#activity-filter-mentions")
    assert has_element?(lv, "#activity-filter-your_grids")
    assert has_element?(lv, "#activity-filter-following")
    assert render(lv) =~ "stream-follower followed you"
    assert render(lv) =~ "stream-follower followed your grid"
    assert render(lv) =~ "Your grid got updates"
    assert render(lv) =~ "stream-author created a new grid"
    assert render(lv) =~ followed_user_graph.title
    assert render(lv) =~ "Followed grid got updates"
    assert has_element?(lv, "#activity-log-#{owned_log.id}")
    assert has_element?(lv, "#activity-log-#{followed_graph_log.id}")
    assert has_element?(lv, ~s(#activity-following-list a[href="/g/#{followed_graph.slug}"]))
    assert has_element?(lv, ~s(#activity-following-list a[href="/u/#{followed_author.username}"]))
  end

  test "filters stream items by mentions, your grids, and following", %{conn: conn} do
    viewer = named_user("filter-viewer")
    follower = named_user("filter-follower")
    followed_author = named_user("filter-author")
    graph_author = named_user("filter-graph-author")
    owned_graph = create_graph(viewer, "filter-owned-grid")
    followed_graph = create_graph(graph_author, "filter-followed-grid")

    assert {:ok, _follow} = Follows.follow_user(follower, viewer)
    assert {:ok, _follow} = Follows.follow_graph(viewer, followed_graph)
    assert {:ok, _follow} = Follows.follow_user(viewer, followed_author)
    followed_user_graph = create_graph(followed_author, "filter-followed-user-grid")

    {:ok, owned_log} =
      GridActivity.record_node_comment_created(owned_graph.title, follower, %{
        id: "2",
        class: "user",
        content: "## Owned grid filter note\n\nUseful detail.",
        parents: []
      })

    {:ok, followed_graph_log} =
      GridActivity.record_node_comment_created(followed_graph.title, graph_author, %{
        id: "3",
        class: "user",
        content: "## Followed grid filter note\n\nGrid detail.",
        parents: []
      })

    {:ok, lv, _html} =
      conn
      |> log_in_user(viewer)
      |> live(~p"/activity")

    lv |> element("#activity-filter-mentions") |> render_click()
    assert render(lv) =~ "filter-follower followed you"
    refute has_element?(lv, "#activity-log-#{owned_log.id}")
    refute has_element?(lv, "#activity-log-#{followed_graph_log.id}")

    lv |> element("#activity-filter-your_grids") |> render_click()
    refute render(lv) =~ "filter-follower followed you"
    assert has_element?(lv, "#activity-log-#{owned_log.id}")
    refute has_element?(lv, "#activity-log-#{followed_graph_log.id}")

    lv |> element("#activity-filter-following") |> render_click()
    refute render(lv) =~ "filter-follower followed you"
    refute has_element?(lv, "#activity-log-#{owned_log.id}")
    assert has_element?(lv, "#activity-log-#{followed_graph_log.id}")
    assert render(lv) =~ followed_user_graph.title
  end
end
