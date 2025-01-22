defmodule DialecticWeb.GraphLive do
  use DialecticWeb, :live_view
  alias Dialectic.Graph.Vertex
  alias Dialectic.Graph.Sample
  alias DialecticWeb.NodeComponent
  alias Dialectic.Graph.Serialise
  alias Dialectic.Graph.GraphActions

  def mount(_params, _session, socket) do
    # graph = Serialise.load_graph()
    graph = Sample.run()

    changeset = Vertex.changeset(%Vertex{})

    {:ok,
     assign(socket,
       graph: graph,
       f_graph: format_graph(graph),
       node: %Vertex{},
       form: to_form(changeset),
       show_combine: false
     )}
  end

  def handle_event("KeyBoardInterface", %{"key" => key, "cmdKey" => isCmd} = params, socket) do
    IO.inspect(params, label: "KeyBoardInterface")

    if isCmd do
      case key do
        "b" ->
          graph = Sample.branch(socket.assigns.graph, socket.assigns.node)

          node = Vertex.add_relatives(graph, socket.assigns.node)
          changeset = Vertex.changeset(node)

          {:noreply,
           assign(socket,
             graph: graph,
             f_graph: format_graph(graph),
             form: to_form(changeset),
             node: node
           )}

        "c" ->
          {:noreply, assign(socket, show_combine: true)}

        _ ->
          {node, changeset} =
            GraphActions.find_node(socket.assigns.graph, key, socket.assigns.node)

          {:noreply,
           assign(socket,
             node: node,
             form: to_form(changeset)
           )}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("node_clicked", %{"id" => id}, socket) do
    {node, changeset} = GraphActions.find_node(socket.assigns.graph, id, socket.assigns.node)

    {:noreply,
     assign(socket,
       node: node,
       form: to_form(changeset)
     )}
  end

  def handle_event("branch", _, socket) do
    graph = Sample.branch(socket.assigns.graph, socket.assigns.node)

    node = Vertex.add_relatives(graph, socket.assigns.node)
    changeset = Vertex.changeset(node)

    {:noreply,
     assign(socket,
       graph: graph,
       f_graph: format_graph(graph),
       form: to_form(changeset),
       node: node
     )}
  end

  def handle_event("answer", %{"vertex" => %{"answer" => answer}}, socket) do
    # Update Node with answer
    node =
      Sample.add_answer(socket.assigns.graph, socket.assigns.node, answer)

    graph = Vertex.update_vertex(socket.assigns.graph, socket.assigns.node, node)

    v = :digraph.vertices(graph)
    # Generate a new node
    child_id = "#{length(v) + 1}"
    description = Dialectic.Responses.LlmInterface.gen_response(answer)
    graph = Sample.add_child(graph, node, child_id, description)

    new_node = Vertex.add_relatives(graph, Vertex.find_node_by_id(graph, child_id))
    changeset = Vertex.changeset(new_node)

    {:noreply,
     assign(socket,
       graph: graph,
       f_graph: format_graph(graph),
       form: to_form(changeset),
       node: new_node
     )}
  end

  def handle_event(
        "combine",
        %{"combine_node" => combine_node},
        socket
      ) do
    {node_id, graph} =
      Sample.combine(
        socket.assigns.graph,
        socket.assigns.node,
        Vertex.find_node_by_id(socket.assigns.graph, combine_node)
      )

    node = Vertex.find_node_by_id(graph, node_id)
    changeset = Vertex.changeset(node)

    {:noreply,
     assign(socket,
       graph: graph,
       f_graph: format_graph(graph),
       form: to_form(changeset),
       node: node
     )}
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
end
