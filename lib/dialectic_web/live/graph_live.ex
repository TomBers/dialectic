defmodule DialecticWeb.GraphLive do
  use DialecticWeb, :live_view
  alias Dialectic.Graph.Vertex
  alias Dialectic.Graph.Serialise
  alias Dialectic.Graph.GraphActions

  alias DialecticWeb.CombineComp

  def mount(_params, _session, socket) do
    # graph = Serialise.load_graph()
    graph = GraphActions.run()
    node = graph |> Vertex.find_node_by_id("1")
    changeset = Vertex.changeset(node)

    {:ok,
     assign(socket,
       graph: graph,
       f_graph: format_graph(graph),
       node: node,
       form: to_form(changeset),
       show_combine: false,
       key_buffer: ""
     )}
  end

  def handle_event("KeyBoardInterface", %{"key" => last_key, "cmdKey" => isCmd}, socket) do
    # IO.inspect(params, label: "KeyBoardInterface")
    key = (socket.assigns.key_buffer <> last_key) |> String.replace_prefix("Control", "")

    if isCmd do
      if socket.assigns.show_combine do
        combine_interface(socket, key)
      else
        main_keybaord_interface(socket, key)
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("node_clicked", %{"id" => id}, socket) do
    update_graph(socket, GraphActions.find_node(socket.assigns.graph, id))
  end

  def handle_event("answer", %{"vertex" => %{"content" => answer}}, socket) do
    update_graph(socket, GraphActions.answer(socket, answer))
  end

  def handle_event("save_graph", _, socket) do
    Serialise.save_graph(socket.assigns.graph)
    {:noreply, socket |> put_flash(:info, "Saved!")}
  end

  def handle_event("modal_closed", _, socket) do
    {:noreply, assign(socket, show_combine: false)}
  end

  def format_graph(graph) do
    graph |> Vertex.to_cytoscape_format() |> Jason.encode!()
  end

  def main_keybaord_interface(socket, key) do
    case key do
      "b" ->
        update_graph(socket, GraphActions.branch(socket))

      "c" ->
        com = Map.get(socket.assigns.node, :id)
        {:noreply, assign(socket, show_combine: !is_nil(com))}

      _ ->
        case GraphActions.find_node(socket.assigns.graph, key) do
          {graph, node} ->
            update_graph(socket, {graph, node}, false)

          _ ->
            {:noreply, assign(socket, key_buffer: key)}
        end
    end
  end

  def combine_interface(socket, key) do
    case GraphActions.combine(socket, key) do
      {graph, node} ->
        update_graph(socket, {graph, node}, true)

      _ ->
        {:noreply, assign(socket, key_buffer: key)}
    end
  end

  def update_graph(socket, {graph, node}, invert_modal \\ false) do
    changeset = Vertex.changeset(node)

    show_combine =
      if invert_modal do
        !socket.assigns.show_combine
      else
        socket.assigns.show_combine
      end

    {:noreply,
     assign(socket,
       graph: graph,
       f_graph: format_graph(graph),
       form: to_form(changeset, id: node.id),
       node: node,
       show_combine: show_combine,
       key_buffer: ""
     )}
  end
end
