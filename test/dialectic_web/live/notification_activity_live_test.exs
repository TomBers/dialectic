defmodule DialecticWeb.NotificationActivityLiveTest do
  use DialecticWeb.ConnCase, async: true

  import Dialectic.AccountsFixtures
  import Phoenix.LiveViewTest

  alias Dialectic.Notifications

  test "redirects if user is not logged in", %{conn: conn} do
    assert {:error, redirect} = live(conn, ~p"/notifications/activity")
    assert {:redirect, %{to: path}} = redirect
    assert path == ~p"/users/log_in"
  end

  test "renders owned graph events", %{conn: conn} do
    user = user_fixture()
    graph = Dialectic.GraphFixtures.insert_graph(%{title: "Owned Activity", user_id: user.id})

    {:ok, _event} =
      Notifications.record_graph_event(graph, %{
        event_type: "graph.updated",
        actor_user: user,
        summary: "Grid updated",
        metadata: %{operation: "comment", node_id: "2"}
      })

    {:ok, view, html} =
      conn
      |> log_in_user(user)
      |> live(~p"/notifications/activity")

    assert html =~ "Notification activity"
    assert has_element?(view, "#notification-events", "Owned Activity")
    assert has_element?(view, "#notification-events", "Comment")
    assert has_element?(view, "#notification-events", "node_id")
  end

  test "switches to followed graph events", %{conn: conn} do
    user = user_fixture()
    actor = user_fixture()
    graph = Dialectic.GraphFixtures.insert_graph(%{title: "Followed Activity"})

    {:ok, _follow} = Notifications.follow_graph(user, graph)

    {:ok, _event} =
      Notifications.record_graph_event(graph, %{
        event_type: "graph.updated",
        actor_user: actor,
        summary: "Followed graph updated",
        metadata: %{operation: "branch"}
      })

    {:ok, view, _html} =
      conn
      |> log_in_user(user)
      |> live(~p"/notifications/activity")

    refute has_element?(view, "#notification-events", "Followed Activity")

    view
    |> element("#notification-scope-followed")
    |> render_click()

    assert has_element?(view, "#followed-grids-list", "Followed Activity")
    assert has_element?(view, "#notification-events", "Followed Activity")
    assert has_element?(view, "#notification-events", "Branch")
  end
end
