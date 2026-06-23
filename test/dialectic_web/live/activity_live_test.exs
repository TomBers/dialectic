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
    assert has_element?(lv, "#activity-tabs")
    assert has_element?(lv, "#activity-tab-feed")
    assert has_element?(lv, "#activity-tab-my-grids")
    assert has_element?(lv, "#activity-tab-following")
    assert has_element?(lv, "#activity-filter-mentions")
    assert has_element?(lv, "#activity-filter-following")
    assert render(lv) =~ "stream-follower followed you"
    assert render(lv) =~ "stream-follower followed your grid"
    assert render(lv) =~ "stream-author created a new grid"
    assert render(lv) =~ followed_user_graph.title
    assert has_element?(lv, "#activity-item-followed-grid-log-#{followed_graph_log.id}")
    refute has_element?(lv, "#activity-log-#{owned_log.id}")

    lv |> element("#activity-tab-my-grids") |> render_click()

    assert render(lv) =~ owned_graph.title
    assert has_element?(lv, "#activity-log-#{owned_log.id}")
    refute has_element?(lv, "#activity-item-followed-grid-log-#{followed_graph_log.id}")
  end

  test "filters feed items and keeps owned grid updates on their own tab", %{conn: conn} do
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
    refute has_element?(lv, "#activity-item-followed-grid-log-#{followed_graph_log.id}")

    lv |> element("#activity-filter-following") |> render_click()
    refute render(lv) =~ "filter-follower followed you"
    refute has_element?(lv, "#activity-log-#{owned_log.id}")
    assert has_element?(lv, "#activity-item-followed-grid-log-#{followed_graph_log.id}")
    assert render(lv) =~ followed_user_graph.title

    lv |> element("#activity-tab-my-grids") |> render_click()

    assert has_element?(lv, "#activity-log-#{owned_log.id}")
    refute has_element?(lv, "#activity-item-followed-grid-log-#{followed_graph_log.id}")
  end

  test "summary chips navigate to related activity areas", %{conn: conn} do
    viewer = named_user("summary-viewer")
    followed_author = named_user("summary-author")
    graph_author = named_user("summary-graph-author")
    owned_graph = create_graph(viewer, "summary-owned-grid")
    followed_graph = create_graph(graph_author, "summary-followed-grid")

    assert {:ok, _follow} = Follows.follow_graph(viewer, followed_graph)
    assert {:ok, _follow} = Follows.follow_user(viewer, followed_author)

    {:ok, owned_log} =
      GridActivity.record_node_comment_created(owned_graph.title, graph_author, %{
        id: "21",
        class: "user",
        content: "## Owned grid summary note\n\nUseful detail.",
        parents: []
      })

    {:ok, followed_graph_log} =
      GridActivity.record_node_comment_created(followed_graph.title, graph_author, %{
        id: "22",
        class: "user",
        content: "## Followed grid summary note\n\nUseful detail.",
        parents: []
      })

    {:ok, lv, _html} =
      conn
      |> log_in_user(viewer)
      |> live(~p"/activity")

    lv |> element("#activity-summary-my-grids") |> render_click()
    assert has_element?(lv, "#activity-log-#{owned_log.id}")

    lv |> element("#activity-summary-following") |> render_click()
    assert has_element?(lv, "#activity-following-list")
    assert render(lv) =~ followed_graph.title
    assert render(lv) =~ followed_author.username
    refute has_element?(lv, "#activity-log-#{owned_log.id}")

    lv |> element("#activity-summary-feed") |> render_click()
    assert has_element?(lv, "#activity-item-followed-grid-log-#{followed_graph_log.id}")
  end

  test "following tab lists followed grids and profiles and can unfollow them", %{conn: conn} do
    viewer = named_user("manage-viewer")
    followed_author = named_user("manage-author")
    graph_author = named_user("manage-graph-author")
    followed_graph = create_graph(graph_author, "manage-followed-grid")

    assert {:ok, graph_follow} = Follows.follow_graph(viewer, followed_graph)
    assert {:ok, user_follow} = Follows.follow_user(viewer, followed_author)

    {:ok, lv, _html} =
      conn
      |> log_in_user(viewer)
      |> live(~p"/activity")

    lv |> element("#activity-tab-following") |> render_click()

    assert has_element?(lv, "#activity-follow-#{graph_follow.id}")
    assert has_element?(lv, "#activity-follow-#{user_follow.id}")

    assert has_element?(
             lv,
             ~s(#activity-follow-#{graph_follow.id} a[href="/g/#{followed_graph.slug}"])
           )

    assert has_element?(
             lv,
             ~s(#activity-follow-#{user_follow.id} a[href="/u/#{followed_author.username}"])
           )

    lv |> element("#activity-unfollow-#{graph_follow.id}") |> render_click()

    refute Follows.following_graph?(viewer, followed_graph)
    refute has_element?(lv, "#activity-follow-#{graph_follow.id}")
    assert has_element?(lv, "#activity-follow-#{user_follow.id}")
    assert render(lv) =~ "Grid unfollowed."

    lv |> element("#activity-unfollow-#{user_follow.id}") |> render_click()

    refute Follows.following_user?(viewer, followed_author)
    refute has_element?(lv, "#activity-follow-#{user_follow.id}")
    assert has_element?(lv, "#activity-following-empty")
    assert render(lv) =~ "Profile unfollowed."
  end

  test "owned grid previews use node title from graph data when activity metadata is sparse", %{
    conn: conn
  } do
    viewer = named_user("node-title-viewer")
    actor = named_user("node-title-actor")

    graph =
      viewer
      |> create_graph("node-title-owned-grid")
      |> Graph.changeset(%{
        data: %{
          "nodes" => [
            %{
              "id" => "42",
              "content" => "# Actual node title\n\nBody text.",
              "class" => "answer"
            }
          ],
          "edges" => []
        }
      })
      |> Dialectic.Repo.update!()

    {:ok, log} = GridActivity.record_node_comment_created(graph.title, actor, "42")

    {:ok, lv, _html} =
      conn
      |> log_in_user(viewer)
      |> live(~p"/activity")

    lv |> element("#activity-tab-my-grids") |> render_click()

    assert has_element?(lv, "#activity-log-#{log.id}")
    assert render(lv) =~ "Actual node title"
    refute render(lv) =~ "Node 42"
  end

  test "mark seen clears new followed activity indicators", %{conn: conn} do
    viewer = named_user("seen-viewer")
    graph_author = named_user("seen-graph-author")
    followed_graph = create_graph(graph_author, "seen-followed-grid")

    assert {:ok, _follow} = Follows.follow_graph(viewer, followed_graph)

    {:ok, followed_graph_log} =
      GridActivity.record_node_comment_created(followed_graph.title, graph_author, %{
        id: "9",
        class: "user",
        content: "## Followed grid seen note\n\nGrid detail.",
        parents: []
      })

    {:ok, lv, _html} =
      conn
      |> log_in_user(viewer)
      |> live(~p"/activity")

    assert render(lv) =~ "1 new"
    assert has_element?(lv, "#activity-item-followed-grid-log-#{followed_graph_log.id}")

    lv |> element("#activity-mark-seen-button") |> render_click()

    refute render(lv) =~ "1 new"
    assert render(lv) =~ "Followed activity marked as seen."
  end
end
