defmodule DialecticWeb.GraphLive do
  use DialecticWeb, :live_view

  alias Dialectic.Graph.{Vertex, GraphActions}
  alias DialecticWeb.{CombineComp, ChatComp, NodeMenuComp}
  alias Dialectic.DbActions.DbWorker

  alias Phoenix.PubSub

  on_mount {DialecticWeb.UserAuth, :mount_current_user}

  def mount(%{"graph_name" => graph_id_uri} = params, _session, socket) do
    graph_id = URI.decode(graph_id_uri)

    PubSub.subscribe(Dialectic.PubSub, "graph_update")

    user =
      case socket.assigns.current_user do
        nil -> "Anon"
        _ -> socket.assigns.current_user.email
      end

    node_id = Map.get(params, "node", "1")

    socket = stream(socket, :presences, [])

    socket =
      if connected?(socket) do
        Phoenix.PubSub.subscribe(Dialectic.PubSub, graph_id)
        DialecticWeb.Presence.track_user(user, %{id: user, graph_id: graph_id})
        DialecticWeb.Presence.subscribe()

        presences =
          DialecticWeb.Presence.list_online_users(graph_id)

        stream(socket, :presences, presences)
      else
        socket
      end

    {graph_struct, graph} = GraphManager.get_graph(graph_id)

    if :digraph.no_vertices(graph) == 1 do
      {_, first_node} = :digraph.vertex(graph, "1")
      GraphActions.answer({graph_id, first_node, user})
    end

    {_, node} = :digraph.vertex(graph, node_id)
    changeset = GraphActions.create_new_node(user) |> Vertex.changeset()

    # TODO - can edit is going to be expaned to be more complex, but for the time being, just is not protected
    can_edit = graph_struct.is_public

    {:ok,
     assign(socket,
       graph_struct: graph_struct,
       graph_id: graph_id,
       graph: graph,
       f_graph: format_graph(graph),
       node: Vertex.add_relatives(node, graph),
       form: to_form(changeset),
       show_combine: false,
       key_buffer: "",
       user: user,
       update_view: true,
       edit: false,
       can_edit: can_edit,
       node_menu_visible: false,
       node_menu_position: nil,
       auto_reply: true,
       drawer_open: false
     )}
  end

  def handle_event("toggle_drawer", _, socket) do
    {:noreply, socket |> assign(drawer_open: !socket.assigns.drawer_open)}
  end

  def handle_event("toggle_auto_reply", _, socket) do
    {:noreply, socket |> assign(auto_reply: !socket.assigns.auto_reply)}
  end

  def handle_event("toggle_lock_graph", _, socket) do
    graph_struct = GraphActions.toggle_graph_locked(graph_action_params(socket))
    can_edit = graph_struct.is_public
    {:noreply, socket |> assign(graph_struct: graph_struct, can_edit: can_edit)}
  end

  def handle_event("show_node_menu", %{"id" => node_id, "node_position" => position}, socket) do
    {:noreply,
     assign(socket,
       node_menu_visible: true,
       selected_node_id: node_id,
       node_menu_position: position
     )}
  end

  def handle_event("update_tooltip_position", %{"position" => position}, socket) do
    {:noreply, assign(socket, node_menu_position: position)}
  end

  def handle_event("note", %{"node" => node_id}, socket) do
    if socket.assigns.current_user == nil do
      {:noreply, socket |> put_flash(:error, "You must be logged in to note")}
    else
      Dialectic.DbActions.Notes.add_note(
        socket.assigns.graph_id,
        node_id,
        socket.assigns.current_user
      )

      update_graph(
        socket,
        GraphActions.change_noted_by(graph_action_params(socket), node_id, &Vertex.add_noted_by/2)
      )
    end
  end

  def handle_event("hide_node_menu", _, socket) do
    {:noreply,
     socket
     |> assign(:node_menu_visible, false)}
  end

  def handle_event("unnote", %{"node" => node_id}, socket) do
    if socket.assigns.current_user == nil do
      {:noreply, socket |> put_flash(:error, "You must be logged in to unnote")}
    else
      Dialectic.DbActions.Notes.remove_note(
        socket.assigns.graph_id,
        node_id,
        socket.assigns.current_user
      )

      update_graph(
        socket,
        GraphActions.change_noted_by(
          graph_action_params(socket),
          node_id,
          &Vertex.remove_noted_by/2
        )
      )
    end
  end

  def handle_event("delete", %{"node" => node_id}, socket) do
    {_graph, node} = GraphActions.find_node(socket.assigns.graph_id, node_id)

    if node.user == socket.assigns.user &&
         length(node.children |> Enum.reject(fn v -> v.deleted end)) == 0 &&
         socket.assigns.can_edit do
      update_graph(
        socket,
        GraphActions.delete_node(graph_action_params(socket), node_id)
      )
    else
      {:noreply, socket |> put_flash(:error, "You cannot delete this node")}
    end
  end

  def handle_event("edit", %{"node" => node_id}, socket) do
    {_graph, node} = GraphActions.find_node(socket.assigns.graph_id, node_id)

    if node.user == socket.assigns.user &&
         length(node.children |> Enum.reject(fn v -> v.deleted end)) == 0 &&
         socket.assigns.can_edit do
      {:noreply, socket |> assign(node: node, form: to_form(Vertex.changeset(node)), edit: true)}
    else
      {:noreply, socket |> put_flash(:error, "Cannot edit node")}
    end
  end

  def handle_event("node_branch", %{"id" => node_id}, socket) do
    if !socket.assigns.can_edit do
      {:noreply, socket |> put_flash(:error, "This graph is locked")}
    else
      {_, node} = GraphActions.find_node(socket.assigns.graph_id, node_id)
      # Ensure branching from the correct node
      update_graph(
        socket,
        GraphActions.branch(graph_action_params(socket, node))
      )
    end
  end

  def handle_event("node_combine", %{"id" => node_id}, socket) do
    if !socket.assigns.can_edit do
      {:noreply, socket |> put_flash(:error, "This graph is locked")}
    else
      {_, node} = GraphActions.find_node(socket.assigns.graph_id, node_id)
      {:noreply, assign(socket, show_combine: true, node: node)}
    end
  end

  def handle_event("combine_node_select", %{"selected_node" => node_id}, socket) do
    if !socket.assigns.can_edit do
      {:noreply, socket |> put_flash(:error, "This graph is locked")}
    else
      {graph, node} =
        GraphActions.combine(
          graph_action_params(socket),
          node_id
        )

      update_graph(socket, {graph, node}, true)
    end
  end

  def handle_event("KeyBoardInterface", %{"key" => last_key, "cmdKey" => isCmd}, socket) do
    # IO.inspect(params, label: "KeyBoardInterface")

    key =
      (socket.assigns.key_buffer <> last_key)
      |> String.replace_prefix("Control", "")

    if isCmd do
      if socket.assigns.show_combine do
        combine_interface(socket, key)
      else
        if last_key == "Control" do
          {:noreply, assign(socket, key_buffer: "")}
        else
          main_keybaord_interface(socket, key)
        end
      end
    else
      if socket.assigns.edit do
        {:noreply, socket}
      else
        case key do
          "ArrowDown" ->
            update_graph(
              socket,
              GraphActions.move(graph_action_params(socket), "down")
            )

          "ArrowUp" ->
            update_graph(
              socket,
              GraphActions.move(graph_action_params(socket), "up")
            )

          "ArrowRight" ->
            update_graph(
              socket,
              GraphActions.move(graph_action_params(socket), "right")
            )

          "ArrowLeft" ->
            update_graph(
              socket,
              GraphActions.move(graph_action_params(socket), "left")
            )

          _ ->
            {:noreply, socket}
        end
      end
    end
  end

  # Handle event when user clicks autocorrect
  def handle_event("KeyBoardInterface", %{}, socket), do: {:noreply, socket}

  def handle_event("node_clicked", %{"id" => id}, socket) do
    update_graph(socket, GraphActions.find_node(socket.assigns.graph_id, id), false, false)
  end

  def handle_event("answer", %{"vertex" => %{"content" => ""}}, socket), do: {:noreply, socket}

  def handle_event("answer", %{"vertex" => %{"content" => answer}}, socket) do
    if socket.assigns.can_edit do
      if socket.assigns.edit do
        update_graph(socket, GraphActions.edit_node(graph_action_params(socket), answer))
      else
        update_graph(socket, GraphActions.comment(graph_action_params(socket), answer))
      end
    else
      {:noreply, socket |> put_flash(:error, "This graph is locked")}
    end
  end

  def handle_event("reply-and-answer", %{"vertex" => %{"content" => answer}} = params, socket) do
    if !socket.assigns.can_edit do
      {:noreply, socket |> put_flash(:error, "This graph is locked")}
    else
      prefix = params["prefix"] || ""
      #  Add a Reply Node and an Answer node
      {_graph, node} = GraphActions.comment(graph_action_params(socket), answer, prefix)

      update_graph(
        socket,
        GraphActions.answer(graph_action_params(socket, node))
      )
    end
  end

  def handle_event("modal_closed", _, socket) do
    {:noreply, assign(socket, show_combine: false)}
  end

  def handle_info({DialecticWeb.Presence, {:join, presence}}, socket) do
    if is_connected_to_graph?(presence, socket.assigns.graph_id) do
      {:noreply, stream_insert(socket, :presences, presence)}
    else
      {:noreply, socket}
    end
  end

  def handle_info({DialecticWeb.Presence, {:leave, presence}}, socket) do
    if presence.metas == [] do
      {:noreply, stream_delete(socket, :presences, presence)}
    else
      {:noreply, stream_insert(socket, :presences, presence)}
    end
  end

  def handle_info({:other_user_change, graph}, socket) do
    {:noreply, assign(socket, graph: graph, f_graph: format_graph(graph))}
  end

  def handle_info({:stream_chunk, updated_vertex, :node_id, node_id}, socket) do
    # This is the streamed LLM response into a node

    if node_id == Map.get(socket.assigns.node, :id) do
      {:noreply, assign(socket, node: updated_vertex)}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:llm_request_complete, node_id}, socket) do
    # Make sure that the graph is saved to the database
    # We pass false so that it does not respect the queue exlusion period and stores the response immediately.
    DbWorker.save_graph(socket.assigns.graph_id, false)

    update_graph(socket, GraphActions.find_node(socket.assigns.graph_id, node_id), false, true)
  end

  def handle_info({:stream_error, error, :node_id, node_id}, socket) do
    # This is the streamed LLM response into a node
    # TODO - broadcast to all users??? - only want to update the node that is being worked on, just rerender the others
    updated_vertex = GraphManager.update_vertex(socket.assigns.graph_id, node_id, error)

    if node_id == Map.get(socket.assigns.node, :id) do
      {:noreply, assign(socket, node: updated_vertex)}
    else
      {:noreply, socket}
    end
  end

  defp is_connected_to_graph?(%{metas: metas}, graph_id) do
    Enum.any?(metas, fn %{graph_id: gid} -> gid == graph_id end)
  end

  def format_graph(graph) do
    graph |> Vertex.to_cytoscape_format() |> Jason.encode!()
  end

  def main_keybaord_interface(socket, key) do
    case key do
      "b" ->
        if !socket.assigns.can_edit do
          {:noreply, socket |> put_flash(:error, "This graph is locked")}
        else
          update_graph(
            socket,
            GraphActions.branch(graph_action_params(socket))
          )
        end

      "r" ->
        if !socket.assigns.can_edit do
          {:noreply, socket |> put_flash(:error, "This graph is locked")}
        else
          update_graph(
            socket,
            GraphActions.answer(graph_action_params(socket))
          )
        end

      "c" ->
        if !socket.assigns.can_edit do
          {:noreply, socket |> put_flash(:error, "This graph is locked")}
        else
          com = Map.get(socket.assigns.node, :id)
          {:noreply, assign(socket, show_combine: !is_nil(com))}
        end

      _ ->
        case GraphActions.find_node(socket.assigns.graph_id, key) do
          {graph, node} ->
            update_graph(socket, {graph, node}, false)

          _ ->
            {:noreply, assign(socket, key_buffer: key)}
        end
    end
  end

  def combine_interface(socket, key) do
    case GraphActions.combine(
           graph_action_params(socket),
           key
         ) do
      {graph, node} ->
        update_graph(socket, {graph, node}, true)

      _ ->
        {:noreply, assign(socket, key_buffer: key)}
    end
  end

  defp graph_action_params(socket, node \\ nil) do
    {socket.assigns.graph_id, node || socket.assigns.node, socket.assigns.user}
  end

  def update_graph(socket, {graph, node}, invert_modal \\ false, update_view \\ true) do
    # Changeset needs to be a new node
    new_node = GraphActions.create_new_node(socket.assigns.user)
    changeset = Vertex.changeset(new_node)

    show_combine =
      if invert_modal do
        !socket.assigns.show_combine
      else
        socket.assigns.show_combine
      end

    if update_view do
      PubSub.broadcast(Dialectic.PubSub, "graph_update", {:other_user_change, graph})
      # Save mutation to database
      DbWorker.save_graph(socket.assigns.graph_id)
    end

    {:noreply,
     assign(socket,
       graph: graph,
       f_graph: format_graph(graph),
       form: to_form(changeset, id: new_node.id),
       node: node,
       show_combine: show_combine,
       key_buffer: "",
       update_view: update_view,
       edit: false
     )}
  end
end
