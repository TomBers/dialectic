defmodule DialecticWeb.GraphLive do
  alias Mix.PubSub
  use DialecticWeb, :live_view
  alias Dialectic.Graph.Vertex
  alias Dialectic.Graph.Serialise
  alias Dialectic.Graph.GraphActions

  alias DialecticWeb.CombineComp
  alias DialecticWeb.ChatComp

  alias Phoenix.PubSub

  def mount(params, _session, socket) do
    PubSub.subscribe(Dialectic.PubSub, "graph_update")
    socket = stream(socket, :presences, [])
    user = params["name"]

    socket =
      if connected?(socket) do
        DialecticWeb.Presence.track_user(user, %{id: user})
        DialecticWeb.Presence.subscribe()
        stream(socket, :presences, DialecticWeb.Presence.list_online_users())
      else
        socket
      end

    graph_id = "Test"
    # graph = Serialise.load_graph()
    graph = GraphManager.get_graph(graph_id)
    # node = graph |> Vertex.find_node_by_id("2") |> Vertex.add_relatives(graph)
    node = GraphActions.create_new_node(user)
    changeset = Vertex.changeset(node)

    {:ok,
     assign(socket,
       graph_id: graph_id,
       graph: graph,
       f_graph: format_graph(graph),
       node: node,
       form: to_form(changeset),
       show_combine: false,
       key_buffer: "",
       user: user
     )}
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
      {:noreply, socket}
    end
  end

  def handle_event("node_clicked", %{"id" => id}, socket) do
    update_graph(socket, GraphActions.find_node(socket.assigns.graph_id, id))
  end

  def handle_event("answer", %{"vertex" => %{"content" => answer}}, socket) do
    update_graph(
      socket,
      GraphActions.answer(socket.assigns.graph_id, socket.assigns.node, answer)
    )
  end

  def handle_event("save_graph", _, socket) do
    Serialise.save_graph(socket.assigns.graph)
    {:noreply, socket |> put_flash(:info, "Saved!")}
  end

  def handle_event("modal_closed", _, socket) do
    {:noreply, assign(socket, show_combine: false)}
  end

  def handle_info({DialecticWeb.Presence, {:join, presence}}, socket) do
    {:noreply, stream_insert(socket, :presences, presence)}
  end

  def handle_info({DialecticWeb.Presence, {:leave, presence}}, socket) do
    if presence.metas == [] do
      {:noreply, stream_delete(socket, :presences, presence)}
    else
      {:noreply, stream_insert(socket, :presences, presence)}
    end
  end

  def handle_info(%{graph: graph}, socket) do
    {:noreply, assign(socket, graph: graph, f_graph: format_graph(graph))}
  end

  def format_graph(graph) do
    graph |> Vertex.to_cytoscape_format() |> Jason.encode!()
  end

  def main_keybaord_interface(socket, key) do
    case key do
      "b" ->
        update_graph(socket, GraphActions.branch(socket.assigns.graph_id, socket.assigns.node))

      "s" ->
        Serialise.save_graph(socket.assigns.graph)
        {:noreply, socket |> put_flash(:info, "Saved!")}

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
    case GraphActions.combine(socket.assigns.graph_id, socket.assigns.node, key) do
      {graph, node} ->
        update_graph(socket, {graph, node}, true)

      _ ->
        {:noreply, assign(socket, key_buffer: key)}
    end
  end

  def update_graph(socket, {graph, node}, invert_modal \\ false) do
    # Changeset needs to be a new node
    new_node = GraphActions.create_new_node(socket.assigns.user)
    changeset = Vertex.changeset(new_node)

    show_combine =
      if invert_modal do
        !socket.assigns.show_combine
      else
        socket.assigns.show_combine
      end

    PubSub.broadcast(Dialectic.PubSub, "graph_update", %{graph: graph})

    {:noreply,
     assign(socket,
       graph: graph,
       f_graph: format_graph(graph),
       form: to_form(changeset, id: new_node.id),
       node: node,
       show_combine: show_combine,
       key_buffer: ""
     )}
  end
end
