defmodule Dialectic.Graph.GraphActions do
  alias Dialectic.Graph.Sample
  alias Dialectic.Graph.Vertex

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

        {graph, node}
    end
  end

  def answer(socket, answer) do
    node =
      Sample.add_answer(socket.assigns.graph, socket.assigns.node, answer)

    graph = Vertex.update_vertex(socket.assigns.graph, socket.assigns.node, node)

    v = :digraph.vertices(graph)
    # Generate a new node
    child_id = "#{length(v) + 1}"
    description = Dialectic.Responses.LlmInterface.gen_response(answer)
    graph = Sample.add_child(graph, node, child_id, description, "answer")

    new_node =
      Vertex.find_node_by_id(graph, child_id)
      |> IO.inspect(label: "New Node")

    {graph, new_node}
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
