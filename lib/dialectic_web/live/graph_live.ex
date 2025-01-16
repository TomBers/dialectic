defmodule DialecticWeb.GraphLive do
  use DialecticWeb, :live_view
  alias Dialectic.Graph.Vertex
  alias Dialectic.Graph.Sample

  def mount(_params, _session, socket) do
    graph = Dialectic.Graph.Sample.run()

    {:ok,
     assign(socket,
       graph: graph,
       f_graph: format_graph(graph),
       drawer_open: false,
       node: nil
     )}
  end

  def handle_event("node_clicked", %{"id" => id}, socket) do
    node = Vertex.find_node_by_id(socket.assigns.graph, id) |> IO.inspect(label: "Node")

    {:noreply,
     assign(socket,
       drawer_open: true,
       node: node
     )}
  end

  def handle_event("generate_thesis", _, socket) do
    graph = Sample.add_child(socket.assigns.graph, socket.assigns.node)

    {:noreply,
     assign(socket,
       graph: graph,
       f_graph: format_graph(graph)
     )}
  end

  def handle_event("close_drawer", _, socket) do
    {:noreply, assign(socket, drawer_open: false)}
  end

  def format_graph(graph) do
    graph |> Vertex.to_cytoscape_format() |> Jason.encode!() |> IO.inspect(label: "FormatGraph")
  end
end
