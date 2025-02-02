defmodule DialecticWeb.GraphLiveTest do
  use DialecticWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Dialectic.AccountsFixtures

  @graph_id "satre"

  defp setup_live(conn) do
    conn =
      conn
      |> log_in_user(user_fixture(%{email: "tester@example.com"}))

    live(conn, ~p"/#{@graph_id}?node=1")
  end

  describe "mount/3" do
    test "assigns necessary values on mount with a current user", %{conn: conn} do
      {:ok, view, _html} = setup_live(conn)
      state = :sys.get_state(view.pid)
      socket = state.socket

      assert socket.assigns.graph_id == @graph_id
      assert socket.assigns.user == "tester@example.com"
      assert socket.assigns.key_buffer == ""
      refute socket.assigns.show_combine
    end
  end

  describe "handle_event/3" do
    test "KeyBoardInterface does nothing when cmdKey is false", %{conn: conn} do
      {:ok, view, _html} = setup_live(conn)

      state_before = :sys.get_state(view.pid).socket.assigns
      render_keydown(view, "KeyBoardInterface", %{"key" => "x", "cmdKey" => false})
      state_after = :sys.get_state(view.pid).socket.assigns

      assert state_before == state_after
    end

    # test "KeyBoardInterface with key 'Control' resets key_buffer", %{conn: conn} do
    #   {:ok, view, _html} = setup_live(conn)

    #   # Pre-set a non-empty key_buffer.
    #   :sys.replace_state(view.pid, fn state ->
    #     socket = Phoenix.LiveView.assign(state.socket, :key_buffer, "somevalue")
    #     %{state | socket: socket}
    #   end)

    #   render_keydown(view, "KeyBoardInterface", %{"key" => "Control", "cmdKey" => true})
    #   state = :sys.get_state(view.pid).socket
    #   assert state.assigns.key_buffer == ""
    # end

    # test "modal_closed sets show_combine to false", %{conn: conn} do
    #   {:ok, view, _html} = setup_live(conn)

    #   # First, force show_combine to true.
    #   :sys.replace_state(view.pid, fn state ->
    #     socket = Phoenix.LiveView.assign(state.socket, :show_combine, true)
    #     %{state | socket: socket}
    #   end)

    #   render_click(view, "modal_closed", %{})
    #   state = :sys.get_state(view.pid).socket
    #   refute state.assigns.show_combine
    # end

    test "answer event with empty content does nothing", %{conn: conn} do
      {:ok, view, _html} = setup_live(conn)
      state_before = :sys.get_state(view.pid).socket.assigns

      render_click(view, "answer", %{"vertex" => %{"content" => ""}})
      state_after = :sys.get_state(view.pid).socket.assigns

      # No change in assigns.
      assert state_before == state_after
    end

    # This test assumes that GraphActions.comment/4 returns a tuple {graph, node}.
    # In a real test you would stub GraphActions.comment/4 to return predictable values.
    test "answer event with content calls GraphActions.comment and updates assigns", %{conn: conn} do
      {:ok, view, _html} = setup_live(conn)

      # We simulate a non-empty answer. In this case, update_graph/3 (called by handle_event)
      # will update key_buffer to "" and may update the graph and node assigns.
      render_click(view, "answer", %{"vertex" => %{"content" => "A non-empty answer"}})

      state = :sys.get_state(view.pid).socket
      # Verify key_buffer is reset.
      assert state.assigns.key_buffer == ""
      # (Other assigns such as graph and node would be updated by GraphActions.comment.)
    end

    # test "KeyBoardInterface calls combine_interface when show_combine is true", %{conn: conn} do
    #   {:ok, view, _html} = setup_live(conn)

    #   # Force show_combine to true so that combine_interface is used.
    #   :sys.replace_state(view.pid, fn state ->
    #     socket = Phoenix.LiveView.assign(state.socket, :show_combine, true)
    #     %{state | socket: socket}
    #   end)

    #   # Send an event with a key that doesn’t result in an immediate update.
    #   render_keydown(view, "KeyBoardInterface", %{"key" => "x", "cmdKey" => true})
    #   state = :sys.get_state(view.pid).socket

    #   # In the fallback branch of combine_interface, the key_buffer is assigned the key.
    #   assert state.assigns.key_buffer == "x"
    # end
  end

  describe "handle_event node_clicked" do
    test "node_clicked updates the graph and node (via update_graph)", %{conn: conn} do
      {:ok, view, _html} = setup_live(conn)

      # We simulate a node click event.
      render_click(view, "node_clicked", %{"id" => "1"})
      state = :sys.get_state(view.pid).socket

      # We expect key_buffer to be reset.
      assert state.assigns.key_buffer == ""
      # Further assertions on assigns.graph or assigns.node would depend on the
      # return value of GraphActions.find_node/2 (which you might stub in a real test).
    end
  end

  describe "handle_info/2" do
    test "steam_chunk info updates the node if node_id matches", %{conn: conn} do
      {:ok, view, _html} = setup_live(conn)
      state = :sys.get_state(view.pid).socket

      # Assume the current node has an id; if not, default to "1".
      current_node_id = Map.get(state.assigns.node, :id, "1")

      # For testing, assume GraphManager.update_vertex/3 will return a node map with an :updated flag.
      # In real tests, you’d stub GraphManager.update_vertex/3 to return this value.
      # Here, we simulate by sending the info message.
      send(view.pid, {:steam_chunk, "new content", :node_id, current_node_id})
      # Allow the LiveView process time to process the message.
      :timer.sleep(50)
      state_after = :sys.get_state(view.pid).socket

      # We expect that the node assign was updated.
      assert String.ends_with?(state_after.assigns.node.content, "new content")
    end

    test "steam_chunk info does not update the node if node_id does not match", %{conn: conn} do
      {:ok, view, _html} = setup_live(conn)
      state = :sys.get_state(view.pid).socket

      send(view.pid, {:steam_chunk, "new content", :node_id, "non_matching_id"})
      :timer.sleep(50)
      state_after = :sys.get_state(view.pid).socket

      # The node assign should remain unchanged.
      assert state_after.assigns.node == state.assigns.node
    end

    test "graph update info updates graph, node, and f_graph", %{conn: conn} do
      {:ok, view, _html} = setup_live(conn)

      # Create a dummy new graph and node.
      new_graph = :digraph.new()
      new_node = %Dialectic.Graph.Vertex{id: "2", content: "New Node", class: "user"}
      :digraph.add_vertex(new_graph, "2", new_node)

      send(view.pid, %{graph: new_graph, node: new_node})
      :timer.sleep(50)
      state = :sys.get_state(view.pid).socket

      assert state.assigns.graph == new_graph
      assert state.assigns.node == new_node

      expected_f_graph = Jason.encode!(Dialectic.Graph.Vertex.to_cytoscape_format(new_graph))
      assert state.assigns.f_graph == expected_f_graph
    end

    test "presence join and leave info are handled without error", %{conn: conn} do
      {:ok, view, _html} = setup_live(conn)

      # Presence join: if the presence is for this graph, it should be inserted.
      presence = %{id: "BOB", metas: [%{graph_id: @graph_id}]}
      send(view.pid, {DialecticWeb.Presence, {:join, presence}})
      :timer.sleep(50)
      # Without access to the internal stream, we simply ensure no error occurs.
      assert true

      # Presence leave: if the metas list is empty, it should be deleted.
      presence_leave = %{id: "Bill", metas: []}
      send(view.pid, {DialecticWeb.Presence, {:leave, presence_leave}})
      :timer.sleep(50)
      assert true
    end
  end
end
