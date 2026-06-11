defmodule Dialectic.FollowsTest do
  use Dialectic.DataCase, async: false

  import Dialectic.AccountsFixtures

  alias Dialectic.Accounts.Graph
  alias Dialectic.DbActions.Graphs
  alias Dialectic.Follows
  alias Dialectic.GridActivity

  defp create_graph(owner, title, attrs \\ %{}) do
    title = "#{title}-#{System.unique_integer([:positive])}"
    {:ok, graph} = Graphs.create_new_graph(title, owner)

    graph
    |> Graph.changeset(Map.merge(%{tags: []}, attrs))
    |> Repo.update!()
  end

  defp activity_node(id) do
    %{
      id: id,
      class: "user",
      content: "## Followed node #{id}\n\nA useful update.",
      parents: []
    }
  end

  test "follows and unfollows graphs, users, and topics" do
    follower = user_fixture()
    author = user_fixture()
    graph = create_graph(author, "follow-target", %{tags: ["ethics"]})

    assert {:ok, _follow} = Follows.follow_graph(follower, graph)
    assert Follows.following_graph?(follower, graph)
    assert {:ok, 1} = Follows.unfollow_graph(follower, graph)
    refute Follows.following_graph?(follower, graph)

    assert {:ok, _follow} = Follows.follow_user(follower, author)
    assert Follows.following_user?(follower, author)
    assert {:error, :self_follow} = Follows.follow_user(follower, follower)

    assert {:ok, _follow} = Follows.follow_topic(follower, " Ethics ")
    assert Follows.following_topic?(follower, "ethics")
    assert {:ok, 1} = Follows.unfollow_topic(follower, "ETHICS")
    refute Follows.following_topic?(follower, "ethics")
  end

  test "activity feed combines followed graph, followed user, topics, and own graphs" do
    follower = user_fixture()
    followed_author = user_fixture()
    graph_author = user_fixture()

    followed_graph = create_graph(graph_author, "followed-graph")
    followed_user_graph = create_graph(followed_author, "followed-user-graph")
    topic_graph = create_graph(graph_author, "topic-graph", %{tags: ["philosophy"]})
    own_private_graph = create_graph(follower, "own-private", %{is_public: false})
    unrelated_graph = create_graph(graph_author, "unrelated-graph")

    assert {:ok, _follow} = Follows.follow_graph(follower, followed_graph)
    assert {:ok, _follow} = Follows.follow_user(follower, followed_author)
    assert {:ok, _follow} = Follows.follow_topic(follower, "philosophy")

    {:ok, followed_graph_log} =
      GridActivity.record_node_comment_created(
        followed_graph.title,
        graph_author,
        activity_node("2")
      )

    {:ok, followed_user_log} =
      GridActivity.record_node_comment_created(
        followed_user_graph.title,
        followed_author,
        activity_node("3")
      )

    {:ok, topic_log} =
      GridActivity.record_node_comment_created(
        topic_graph.title,
        graph_author,
        activity_node("4")
      )

    {:ok, own_log} =
      GridActivity.record_node_comment_created(
        own_private_graph.title,
        follower,
        activity_node("5")
      )

    {:ok, unrelated_log} =
      GridActivity.record_node_comment_created(
        unrelated_graph.title,
        graph_author,
        activity_node("6")
      )

    feed_ids = follower |> Follows.list_activity_feed(limit: 20) |> Enum.map(& &1.id)

    assert followed_graph_log.id in feed_ids
    assert followed_user_log.id in feed_ids
    assert topic_log.id in feed_ids
    assert own_log.id in feed_ids
    refute unrelated_log.id in feed_ids
  end

  test "activity feed does not expose private graphs owned by followed users" do
    follower = user_fixture()
    followed_author = user_fixture()

    private_graph =
      create_graph(followed_author, "private-followed-user-graph", %{is_public: false})

    assert {:ok, _follow} = Follows.follow_user(follower, followed_author)

    {:ok, private_log} =
      GridActivity.record_node_comment_created(
        private_graph.title,
        followed_author,
        activity_node("7")
      )

    feed_ids = follower |> Follows.list_activity_feed(limit: 20) |> Enum.map(& &1.id)

    refute private_log.id in feed_ids
  end
end
