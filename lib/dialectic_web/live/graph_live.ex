defmodule DialecticWeb.GraphLive do
  use DialecticWeb, :live_view
  alias Dialectic.Graph.Vertex
  alias Dialectic.Graph.Sample
  alias DialecticWeb.NodeComponent

  def mount(_params, _session, socket) do
    graph = Dialectic.Graph.Sample.run()

    changeset = Vertex.changeset(%Vertex{})

    {:ok,
     assign(socket,
       graph: graph,
       f_graph: format_graph(graph),
       drawer_open: true,
       node: %Vertex{},
       form: to_form(changeset)
     )}
  end

  def handle_event("node_clicked", %{"id" => id}, socket) do
    node = Vertex.find_node_by_id(socket.assigns.graph, id)
    node = Vertex.add_relatives(socket.assigns.graph, node)
    changeset = Vertex.changeset(node)

    {:noreply,
     assign(socket,
       drawer_open: true,
       node: node,
       form: to_form(changeset)
     )}
  end

  def handle_event("generate_thesis", _, socket) do
    graph = Sample.add_child(socket.assigns.graph, socket.assigns.node)
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

  def handle_event("save", %{"vertex" => %{"description" => description}}, socket) do
    new_node = %{socket.assigns.node | description: description}
    graph = Vertex.update_vertex(socket.assigns.graph, socket.assigns.node, new_node)
    changeset = Vertex.changeset(new_node)

    {:noreply,
     assign(socket,
       graph: graph,
       f_graph: format_graph(graph),
       form: to_form(changeset)
     )}
  end

  def handle_event("close_drawer", _, socket) do
    {:noreply, assign(socket, drawer_open: false)}
  end

  def format_graph(graph) do
    graph |> Vertex.to_cytoscape_format() |> Jason.encode!()
  end
end
