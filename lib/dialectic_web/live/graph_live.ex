defmodule DialecticWeb.GraphLive do
  use DialecticWeb, :live_view
  alias Dialectic.Graph.Vertex
  alias Dialectic.Graph.Sample

  def mount(_params, _session, socket) do
    graph = Dialectic.Graph.Sample.run()
    {:ok, assign(socket, graph: graph, f_graph: format_graph(graph), drawer_open: false)}
  end

  def handle_event("node_clicked", %{"id" => id}, socket) do
    # IO.inspect(id, label: "Node ID")
    # IO.inspect(socket.assigns.graph)
    graph = Sample.add_child(socket.assigns.graph, id)
    IO.inspect(graph |> Vertex.to_cytoscape_format(), label: "Updated")
    {:noreply, assign(socket, graph: graph, f_graph: format_graph(graph), drawer_open: true)}
  end

  def handle_event("close_drawer", _, socket) do
    {:noreply, assign(socket, drawer_open: false)}
  end

  def format_graph(graph) do
    graph |> Vertex.to_cytoscape_format() |> Jason.encode!() |> IO.inspect(label: "FormatGraph")
  end
end
