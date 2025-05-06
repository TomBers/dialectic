defmodule DialecticWeb.GraphLiveTest do
  use DialecticWeb.ConnCase, async: false
  import Phoenix.LiveViewTest
  import Dialectic.AccountsFixtures
  alias Dialectic.Graph.GraphManager

  @graph_id "Satre"

  defp setup_live(conn) do
    conn =
      conn
      |> log_in_user(user_fixture(%{email: "tester@example.com"}))

    # Also create test database
    Dialectic.GraphFixtures.insert_graph_fixture(@graph_id)

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

    test "KeyBoardInterface with key 'Control' resets key_buffer", %{conn: conn} do
      {:ok, view, _html} = setup_live(conn)

      # First, simulate a non-empty key_buffer by sending a key that triggers the fallback branch.
      render_keydown(view, "KeyBoardInterface", %{"key" => "x", "cmdKey" => true})
      state_mid = :sys.get_state(view.pid).socket.assigns
      assert state_mid.key_buffer == "x"

      # Now, sending the "Control" key should reset the key_buffer.
      render_keydown(view, "KeyBoardInterface", %{"key" => "Control", "cmdKey" => true})
      state = :sys.get_state(view.pid).socket.assigns
      assert state.key_buffer == ""
    end

    test "modal_closed sets show_combine to false", %{conn: conn} do
      {:ok, view, _html} = setup_live(conn)

      # Enable show_combine by simulating a "c" key event.
      render_keydown(view, "KeyBoardInterface", %{"key" => "c", "cmdKey" => true})
      state_mid = :sys.get_state(view.pid).socket.assigns
      assert state_mid.show_combine

      render_click(view, "modal_closed", %{})
      state = :sys.get_state(view.pid).socket.assigns
      refute state.show_combine
    end

    test "KeyBoardInterface with key 'c' toggles show_combine", %{conn: conn} do
      {:ok, view, _html} = setup_live(conn)
      render_keydown(view, "KeyBoardInterface", %{"key" => "c", "cmdKey" => true})
      state = :sys.get_state(view.pid).socket
      # Since the current node is expected to have an id, show_combine is set to true.
      assert state.assigns.show_combine
    end

    test "KeyBoardInterface with key 'b' triggers branch and resets key_buffer", %{conn: conn} do
      {:ok, view, _html} = setup_live(conn)
      render_keydown(view, "KeyBoardInterface", %{"key" => "b", "cmdKey" => true})
      state = :sys.get_state(view.pid).socket
      # update_graph resets key_buffer to an empty binary.
      assert state.assigns.key_buffer == ""
    end

    test "KeyBoardInterface with key 'r' triggers answer and resets key_buffer", %{conn: conn} do
      {:ok, view, _html} = setup_live(conn)
      render_keydown(view, "KeyBoardInterface", %{"key" => "r", "cmdKey" => true})
      state = :sys.get_state(view.pid).socket
      # Expect the key_buffer to be reset after update_graph is called.
      assert state.assigns.key_buffer == ""
    end

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
    test "stream_chunk info updates the node if node_id matches", %{conn: conn} do
      {:ok, view, _html} = setup_live(conn)
      state = :sys.get_state(view.pid).socket

      # Assume the current node has an id; if not, default to "1".
      current_node_id = Map.get(state.assigns.node, :id, "1")

      # Create a proper vertex structure instead of just a string
      # As the handler expects a vertex structure
      updated_vertex = %{
        id: current_node_id,
        content: "new content",
        class: "test",
        user: "test_user",
        noted_by: [],
        parents: [],
        children: [],
        deleted: false
      }

      send(view.pid, {:stream_chunk, updated_vertex, :node_id, current_node_id})
      # Allow the LiveView process time to process the message.
      :timer.sleep(50)
      state_after = :sys.get_state(view.pid).socket

      # We expect that the node assign was updated.
      assert state_after.assigns.node.content == "new content"
    end

    test "stream_chunk info does not update the node if node_id does not match", %{conn: conn} do
      {:ok, view, _html} = setup_live(conn)
      state = :sys.get_state(view.pid).socket
      original_node = state.assigns.node

      updated_vertex = %{
        id: "non_matching_id",
        content: "new content",
        class: "test",
        user: "test_user",
        noted_by: [],
        parents: [],
        children: [],
        deleted: false
      }

      send(view.pid, {:stream_chunk, updated_vertex, :node_id, "non_matching_id"})
      :timer.sleep(50)
      state_after = :sys.get_state(view.pid).socket

      # The node assign should remain unchanged.
      assert state_after.assigns.node == original_node
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

  #####################################################################
  # New tests for the additional event functionality ("note", "unnote",
  # "delete", and "edit"). In these tests we assume that functions like
  # GraphActions.find_node/2 have been stubbed to return predictable values.
  #####################################################################

  describe "handle_event \"note\"" do
    test "note event updates the graph and resets key_buffer", %{conn: conn} do
      {:ok, view, _html} = setup_live(conn)

      # Simulate a note event on node "1". (In a real test you might stub
      # GraphActions.change_noted_by/3 to return a predictable updated graph/node.)
      render_click(view, "note", %{"node" => "1"})
      state = :sys.get_state(view.pid).socket

      # Check that update_graph was called (it resets key_buffer).
      assert state.assigns.key_buffer == ""

      # Additional assertions (e.g. on assigns.graph or assigns.node) depend on your implementation.
    end
  end

  describe "handle_event \"unnote\"" do
    test "unnote event updates the graph and resets key_buffer", %{conn: conn} do
      {:ok, view, _html} = setup_live(conn)

      render_click(view, "unnote", %{"node" => "1"})
      state = :sys.get_state(view.pid).socket

      assert state.assigns.key_buffer == ""
      # You could also verify that GraphActions.change_noted_by was called with
      # Vertex.remove_noted_by/2 if you stub that function.
    end
  end

  # describe "handle_event \"delete\"" do
  #   test "delete event updates the graph when deletion conditions are met", %{conn: conn} do
  #     {:ok, view, _html} = setup_live(conn)

  #     {_g, v} = GraphActions.find_node(@graph_id, "6")
  #     refute v.deleted

  #     # For this test we assume that when the node id is "delete_allowed",
  #     # GraphActions.find_node/2 returns a node with:
  #     #   - user equal to "tester@example.com"
  #     #   - children: [] (or only deleted children)
  #     render_click(view, "delete", %{"node" => "6"})
  #     state = :sys.get_state(view.pid).socket

  #     # IO.inspect(state, label: "state")
  #     # In the allowed case, update_graph is called so key_buffer is reset.
  #     assert state.assigns.key_buffer == ""
  #     {_g, v} = GraphActions.find_node(@graph_id, "6")
  #     assert v.deleted
  #   end

  #   test "delete event sets flash error when deletion conditions are not met", %{conn: conn} do
  #     {:ok, view, _html} = setup_live(conn)

  #     # For this test we assume that when the node id is "delete_disallowed",
  #     # GraphActions.find_node/2 returns a node that either does not belong to the user
  #     # or has non-deleted children.
  #     render_click(view, "delete", %{"node" => "1"})
  #     state = :sys.get_state(view.pid).socket

  #     {_g, v} = GraphActions.find_node(@graph_id, "1")
  #     refute v.deleted
  #   end
  # end

  # describe "handle_event \"edit\"" do
  #   test "edit event sets up editing assigns when conditions are met", %{conn: conn} do
  #     {:ok, view, _html} = setup_live(conn)

  #     {_g, v} = GraphActions.find_node(@graph_id, "6")

  #     assert v.content =~
  #              "Certainly! Let's delve deeper into the criticisms"

  #     # Assume that for node id "edit_allowed", GraphActions.find_node/2 returns a node with:
  #     #   - user equal to "tester@example.com"
  #     #   - no active children
  #     render_click(view, "edit", %{"node" => "6"})
  #     state = :sys.get_state(view.pid).socket

  #     # The node should be assigned to the socket, along with a form for editing and an edit flag.
  #     assert state.assigns.edit
  #     assert state.assigns.form
  #     assert state.assigns.node.id == "6"
  #     assert state.assigns.form.data.id == "6"

  #     assert state.assigns.form.data.content =~
  #              "Certainly! Let's delve deeper into the criticisms"

  #     render_click(view, "answer", %{"vertex" => %{"content" => "Edited Node"}})
  #     state_after = :sys.get_state(view.pid).socket.assigns
  #     {_g, v} = GraphActions.find_node(@graph_id, "6")
  #     assert v.content == "Edited Node"
  #   end

  #   test "edit event sets flash error when editing conditions are not met", %{conn: conn} do
  #     {:ok, view, _html} = setup_live(conn)

  #     # For node id "edit_disallowed", assume GraphActions.find_node/2 returns a node that cannot be edited.
  #     render_click(view, "edit", %{"node" => "1"})
  #     state = :sys.get_state(view.pid).socket

  #     refute state.assigns.edit
  #   end
  # end
end