defmodule Dialectic.Graph.GraphActions do
  alias Dialectic.Graph.Sample
  alias Dialectic.Graph.Vertex

  def answer(socket, answer) do
    Sample.answer(socket.assigns.graph, socket.assigns.node, answer)
  end

  def branch(socket) do
    Sample.branch(socket.assigns.graph, socket.assigns.node)
  end

  def combine(socket, combine_node_id) do
    case Vertex.find_node_by_id(socket.assigns.graph, combine_node_id) do
      nil ->
        nil

      combine_node ->
        Sample.combine(
          socket.assigns.graph,
          socket.assigns.node,
          combine_node
        )
    end
  end

  def find_node(graph, id) do
    case Vertex.find_node_by_id(graph, id) do
      nil ->
        nil

      node ->
        {graph, Vertex.add_relatives(node, graph)}
    end
  end
end
