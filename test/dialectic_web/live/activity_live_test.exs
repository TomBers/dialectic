defmodule DialecticWeb.ActivityLiveTest do
  use DialecticWeb.ConnCase, async: false

  import Dialectic.AccountsFixtures
  import Phoenix.LiveViewTest

  alias Dialectic.Accounts.Graph
  alias Dialectic.DbActions.Graphs
  alias Dialectic.Follows
  alias Dialectic.GridActivity

  defp create_graph(owner, title, attrs) do
    title = "#{title}-#{System.unique_integer([:positive])}"
    {:ok, graph} = Graphs.create_new_graph(title, owner)

    graph
    |> Graph.changeset(Map.merge(%{tags: []}, attrs))
    |> Dialectic.Repo.update!()
  end

  test "requires authentication", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/users/log_in"}}} = live(conn, ~p"/activity")
  end

  test "renders followed activity and topic controls", %{conn: conn} do
    viewer = user_fixture()
    author = user_fixture()
    graph = create_graph(author, "activity-topic", %{tags: ["epistemology"]})

    assert {:ok, _follow} = Follows.follow_topic(viewer, "epistemology")

    {:ok, log} =
      GridActivity.record_node_comment_created(graph.title, author, %{
        id: "2",
        class: "user",
        content: "## A new note\n\nUseful detail.",
        parents: []
      })

    {:ok, lv, _html} =
      conn
      |> log_in_user(viewer)
      |> live(~p"/activity")

    assert has_element?(lv, "#activity-topic-follow-form")
    assert has_element?(lv, "#activity-following-list", "#epistemology")
    assert has_element?(lv, "#activity-log-#{log.id}", graph.title)

    lv
    |> form("#activity-topic-follow-form", %{"topic" => %{"name" => "logic"}})
    |> render_submit()

    assert Follows.following_topic?(viewer, "logic")
  end
end
