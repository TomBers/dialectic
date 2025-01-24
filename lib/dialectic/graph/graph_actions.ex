defmodule Dialectic.Graph.GraphActions do
  alias Dialectic.Graph.Vertex
  alias Dialectic.Responses.LlmInterface

  def run do
    # graph =
    :digraph.new()
    # add_node(graph, "1", Dialectic.Responses.LlmInterface.gen_response("First"), "answer")
    # graph
  end

  def create_new_node(graph) do
    new_node_id = gen_id(graph)
    %Vertex{id: new_node_id} |> Vertex.add_relatives(graph)
  end

  def add_node(graph, name, content, class \\ "") do
    vertex = %Vertex{id: name, content: content, class: class}
    :digraph.add_vertex(graph, name, vertex)
    vertex
  end

  def answer(socket, answer) when is_map(socket) do
    answer(socket.assigns.graph, socket.assigns.node, answer)
  end

  def answer(graph, node, question) do
    parents = if length(node.parents) == 0, do: [], else: [node]

    {graph_with_question, question_node} =
      add_child(graph, parents, gen_id(graph), question, "user")

    add_child(
      graph_with_question,
      [question_node],
      gen_id(graph_with_question),
      LlmInterface.gen_response(question),
      "answer"
    )
  end

  def branch(socket) when is_map(socket) do
    branch(socket.assigns.graph, socket.assigns.node)
  end

  def branch(graph, node) do
    thesis_id = gen_id(graph)
    antithesis_id = gen_id(graph, 1)

    {g1, _} =
      graph
      |> add_child([node], thesis_id, LlmInterface.gen_thesis(node), "thesis")

    add_child(g1, [node], antithesis_id, LlmInterface.gen_antithesis(node), "antithesis")
  end

  def combine(socket, combine_node_id) when is_map(socket) do
    case Vertex.find_node_by_id(socket.assigns.graph, combine_node_id) do
      nil ->
        nil

      combine_node ->
        combine(socket.assigns.graph, socket.assigns.node, combine_node)
    end
  end

  def combine(graph, node1, node2) do
    synthesis_id = gen_id(graph)

    add_child(
      graph,
      [node1, node2],
      synthesis_id,
      LlmInterface.gen_synthesis(node1, node2),
      "synthesis"
    )
  end

  def find_node(graph, id) do
    case Vertex.find_node_by_id(graph, id) do
      nil ->
        nil

      node ->
        {graph, Vertex.add_relatives(node, graph)}
    end
  end

  defp gen_id(graph, offset \\ 0) do
    v = :digraph.vertices(graph)
    "#{length(v) + 1 + offset}"
  end

  defp add_child(graph, parents, child_id, description, class) do
    node = add_node(graph, child_id, description, class)
    Enum.each(parents, fn parent -> :digraph.add_edge(graph, parent.id, child_id) end)
    {graph, node |> Vertex.add_relatives(graph)}
  end
end
