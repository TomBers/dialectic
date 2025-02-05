defmodule DialecticWeb.GraphLive do
  use DialecticWeb, :live_view

  alias Dialectic.Graph.{Vertex, GraphActions}
  alias DialecticWeb.{CombineComp, ChatComp}

  on_mount {DialecticWeb.UserAuth, :mount_current_user}

  def mount(%{"graph_name" => graph_id} = params, _session, socket) do
    user =
      case socket.assigns.current_user do
        nil -> "Anon"
        _ -> socket.assigns.current_user.email
      end

    node_id = Map.get(params, "node", "1")

    socket = stream(socket, :presences, [])

    socket =
      if connected?(socket) do
        DialecticWeb.Presence.track_user(user, %{id: user, graph_id: graph_id})
        DialecticWeb.Presence.subscribe()

        presences =
          DialecticWeb.Presence.list_online_users(graph_id)

        stream(socket, :presences, presences)
      else
        socket
      end

    graph = GraphManager.get_graph(graph_id)

    {_, node} = :digraph.vertex(graph, node_id)
    changeset = GraphActions.create_new_node(user) |> Vertex.changeset()

    {:ok,
     assign(socket,
       graph_id: graph_id,
       graph: graph,
       f_graph: format_graph(graph),
       node: Vertex.add_relatives(node, graph),
       form: to_form(changeset),
       show_combine: false,
       key_buffer: "",
       user: user,
       update_view: true
     )}
  end

  def handle_event("note", %{"node" => node_id}, socket) do
    update_graph(
      socket,
      GraphActions.change_noted_by(graph_action_params(socket), node_id, &Vertex.add_noted_by/2)
    )
  end

  def handle_event("unnote", %{"node" => node_id}, socket) do
    update_graph(
      socket,
      GraphActions.change_noted_by(
        graph_action_params(socket),
        node_id,
        &Vertex.remove_noted_by/2
      )
    )
  end

  def handle_event("KeyBoardInterface", %{"key" => last_key, "cmdKey" => isCmd}, socket) do
    # IO.inspect(params, label: "KeyBoardInterface")
    key =
      (socket.assigns.key_buffer <> last_key)
      |> String.replace_prefix("Control", "")
      |> IO.inspect(label: "KeyBuffer")

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

  def handle_event("node_clicked", %{"id" => id}, socket) do
    update_graph(socket, GraphActions.find_node(socket.assigns.graph_id, id), false, false)
  end

  def handle_event("answer", %{"vertex" => %{"content" => ""}}, socket), do: {:noreply, socket}

  def handle_event("answer", %{"vertex" => %{"content" => answer}}, socket) do
    update_graph(
      socket,
      GraphActions.comment(graph_action_params(socket), answer)
    )
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

  def handle_info({:stream_chunk, chunk, :node_id, node_id}, socket) do
    # This is the streamed LLM response into a node
    # TODO - broadcast to all users??? - only want to update the node that is being worked on, just rerender the others
    updated_vertex = GraphManager.update_vertex(socket.assigns.graph_id, node_id, chunk)

    if node_id == Map.get(socket.assigns.node, :id) do
      {:noreply, assign(socket, node: updated_vertex)}
    else
      {:noreply, socket}
    end
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

  defp is_connected_to_graph?(
         %{
           metas: [%{graph_id: user_graph_id}]
         },
         graph_id
       ),
       do: user_graph_id == graph_id

  def format_graph(graph) do
    graph |> Vertex.to_cytoscape_format() |> Jason.encode!()
  end

  def main_keybaord_interface(socket, key) do
    case key do
      "b" ->
        update_graph(
          socket,
          GraphActions.branch(graph_action_params(socket))
        )

      "r" ->
        update_graph(
          socket,
          GraphActions.answer(graph_action_params(socket))
        )

      "c" ->
        com = Map.get(socket.assigns.node, :id)
        {:noreply, assign(socket, show_combine: !is_nil(com))}

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

  defp graph_action_params(socket) do
    {socket.assigns.graph_id, socket.assigns.node, socket.assigns.user, self()}
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

    # PubSub.broadcast(Dialectic.PubSub, "graph_update", graph)

    {:noreply,
     assign(socket,
       graph: graph,
       f_graph: format_graph(graph),
       form: to_form(changeset, id: new_node.id),
       node: node,
       show_combine: show_combine,
       key_buffer: "",
       update_view: update_view
     )}
  end
end
