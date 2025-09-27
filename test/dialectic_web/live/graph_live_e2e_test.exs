defmodule DialecticWeb.GraphLiveE2ETest do
  use DialecticWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Dialectic.AccountsFixtures

  @graph_id "E2EGraph"

  defp setup_live(conn) do
    user = user_fixture(%{email: "e2e_tester@example.com"})

    conn =
      conn
      |> log_in_user(user)

    {:ok, _graph} = Dialectic.DbActions.Graphs.create_new_graph(@graph_id)

    {:ok, view, _html} = live(conn, ~p"/#{@graph_id}?node=1")

    %{view: view, user: user}
  end

  defp get_socket_assigns(view) do
    :sys.get_state(view.pid).socket.assigns
  end

  defp vertices_count(graph) do
    graph
    |> :digraph.vertices()
    |> length()
  end

  defp find_vertex_by_class(graph, class) do
    :digraph.vertices(graph)
    |> Enum.find_value(fn vid ->
      case :digraph.vertex(graph, vid) do
        {^vid, v} ->
          if Map.get(v, :class) == class, do: v, else: nil

        _ ->
          nil
      end
    end)
  end

  defp get_vertex(graph, vid) do
    case :digraph.vertex(graph, vid) do
      {^vid, v} -> v
      _ -> nil
    end
  end

  describe "GraphLive end-to-end interactions" do
    test "node click, answer, delete, branch, combine, move, related ideas, branch list, explore submit, reply-and-answer, note/unnote, toggle lock",
         %{
           conn: conn
         } do
      %{view: view, user: user} = setup_live(conn)

      # Initial state
      assigns = get_socket_assigns(view)
      initial_graph = assigns.graph
      initial_node = assigns.node
      initial_vcount = vertices_count(initial_graph)
      assert initial_node.id

      # 1) Node click navigates/focuses a node
      render_click(view, "node_clicked", %{"id" => initial_node.id})
      assigns = get_socket_assigns(view)
      assert assigns.node.id == initial_node.id

      # 2) "answer" with content creates a new child node (class "user") and updates the graph (GraphActions.comment)
      render_click(view, "answer", %{"vertex" => %{"content" => "A new idea"}})
      assigns = get_socket_assigns(view)
      after_answer_graph = assigns.graph
      assert vertices_count(after_answer_graph) > initial_vcount

      new_node = assigns.node
      assert new_node.class == "user"

      # Capture id for later delete test
      new_node_id = new_node.id

      # 3) Delete the newly created node (GraphActions.delete_node)
      before_del_vcount = vertices_count(after_answer_graph)
      render_click(view, "delete_node", %{"node" => new_node_id})

      assigns = get_socket_assigns(view)
      after_delete_graph = assigns.graph
      deleted_vertex = get_vertex(after_delete_graph, new_node_id)
      assert deleted_vertex == nil or Map.get(deleted_vertex, :deleted, false)
      assert vertices_count(after_delete_graph) <= before_del_vcount

      # 4) Create another answer node that we'll branch from
      render_click(view, "answer", %{"vertex" => %{"content" => "Branch from here"}})
      assigns = get_socket_assigns(view)
      branch_parent = assigns.node
      assert branch_parent.class == "user"

      before_branch_vcount = vertices_count(assigns.graph)

      # 5) Branch to thesis & antithesis (GraphActions.branch)
      render_click(view, "node_branch", %{"id" => branch_parent.id})
      assigns = get_socket_assigns(view)
      after_branch_graph = assigns.graph
      assert vertices_count(after_branch_graph) >= before_branch_vcount + 2

      # Find a thesis node for combining (GraphActions.combine)
      thesis = find_vertex_by_class(after_branch_graph, "thesis")
      assert thesis

      # 6) Open combine UI and combine with thesis -> creates synthesis
      render_click(view, "node_combine", %{"id" => branch_parent.id})
      assigns = get_socket_assigns(view)
      assert assigns.show_combine

      render_click(view, "combine_node_select", %{"selected_node" => thesis.id})
      assigns = get_socket_assigns(view)
      synthesis = find_vertex_by_class(assigns.graph, "synthesis")
      assert synthesis

      # 7) Move selection (GraphActions.move) - verifies event path executes without error
      prev_node_id = assigns.node.id
      render_click(view, "node_move", %{"direction" => "right"})
      assigns = get_socket_assigns(view)
      assert assigns.node.id

      # 8) Related ideas (GraphActions.related_ideas) - adds a child; assigns.graph should grow
      before_ideas_vcount = vertices_count(assigns.graph)
      render_click(view, "node_related_ideas", %{"id" => assigns.node.id})
      assigns = get_socket_assigns(view)
      assert vertices_count(assigns.graph) > before_ideas_vcount

      # 9) Branch list (GraphActions.answer_selection for each item) - graph mutates in GraphManager
      {_, graph_before_bl} = GraphManager.get_graph(@graph_id)
      vcount_before_bl = length(:digraph.vertices(graph_before_bl))
      render_click(view, "branch_list", %{"items" => ["Point A", "Point B"]})
      {_, graph_after_bl} = GraphManager.get_graph(@graph_id)
      vcount_after_bl = length(:digraph.vertices(graph_after_bl))
      assert vcount_after_bl >= vcount_before_bl + 2

      # 10) Explore modal submit (GraphActions.answer_selection for selected items)
      # Open modal first
      render_click(view, "open_explore_modal", %{"items" => ["X", "Y"]})
      assigns = get_socket_assigns(view)
      assert assigns.show_explore_modal

      {_, graph_before_explore} = GraphManager.get_graph(@graph_id)
      vcount_before_explore = length(:digraph.vertices(graph_before_explore))

      # Submit explore with two "selected" items (map form to exercise normalizer)
      render_click(view, "submit_explore_modal", %{
        "items" => %{"Alpha" => "on", "Beta" => "true"}
      })

      {_, graph_after_explore} = GraphManager.get_graph(@graph_id)
      vcount_after_explore = length(:digraph.vertices(graph_after_explore))
      assert vcount_after_explore >= vcount_before_explore + 2

      assigns = get_socket_assigns(view)
      refute assigns.show_explore_modal

      # 11) reply-and-answer (GraphActions.answer_selection with a prefix)
      {_, graph_before_reply} = GraphManager.get_graph(@graph_id)
      vcount_before_reply = length(:digraph.vertices(graph_before_reply))

      render_click(view, "reply-and-answer", %{
        "vertex" => %{"content" => "Please explain Z"},
        "prefix" => "explain"
      })

      {_, graph_after_reply} = GraphManager.get_graph(@graph_id)
      vcount_after_reply = length(:digraph.vertices(graph_after_reply))
      assert vcount_after_reply >= vcount_before_reply + 1

      # 12) Note and unnote flows on the currently selected node (GraphActions.change_noted_by)
      current_node_id = assigns.node.id

      render_click(view, "note", %{"node" => current_node_id})
      assigns = get_socket_assigns(view)
      noted_vertex = get_vertex(assigns.graph, current_node_id)

      if noted_vertex do
        assert user.email in Map.get(noted_vertex, :noted_by, [])
      end

      render_click(view, "unnote", %{"node" => current_node_id})
      assigns = get_socket_assigns(view)
      unnoted_vertex = get_vertex(assigns.graph, current_node_id)

      if unnoted_vertex do
        refute user.email in Map.get(unnoted_vertex, :noted_by, [])
      end

      # 13) Toggle lock/unlock (GraphActions.toggle_graph_locked through GraphManager)
      render_click(view, "toggle_lock_graph", %{})
      assigns = get_socket_assigns(view)
      refute assigns.can_edit

      render_click(view, "toggle_lock_graph", %{})
      assigns = get_socket_assigns(view)
      assert assigns.can_edit

      # Ensure move didn't crash earlier and node id remains valid
      assert prev_node_id
    end
  end
end
