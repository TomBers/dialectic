defmodule Dialectic.Graph.GraphActions do
  alias Dialectic.Graph.Sample
  alias Dialectic.Graph.Vertex

  def answer(socket, answer) do
    Sample.answer(socket.assigns.graph, socket.assigns.node, answer)
  end

  def branch(socket) do
    graph = Sample.branch(socket.assigns.graph, socket.assigns.node)
    node = Vertex.add_relatives(graph, socket.assigns.node)

    {graph, node}
  end

  def combine(socket, combine_node_id) do
    case Vertex.find_node_by_id(socket.assigns.graph, combine_node_id) do
      nil ->
        nil

      combine_node ->
        {node_id, graph} =
          Sample.combine(
            socket.assigns.graph,
            socket.assigns.node,
            combine_node
          )

        node = Vertex.find_node_by_id(graph, node_id)

        {graph, Vertex.add_relatives(graph, node)}
    end
  end

  def find_node(graph, id) do
    case Vertex.find_node_by_id(graph, id) do
      nil ->
        nil

      node ->
        {graph, Vertex.add_relatives(graph, node)}
    end
  end
end
