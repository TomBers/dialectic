defmodule Dialectic.Graph.Sample do
  alias Dialectic.Graph.Vertex
  alias Dialectic.Responses.LlmInterface

  # To test - Graph A -> B, A -> C, B -> D and C -> D
  def run do
    graph = :digraph.new()

    # v1 =
    add_node(graph, "1", Dialectic.Responses.LlmInterface.gen_response("First"), "answer")
    # v2 = add_node(graph, "2")
    # v3 = add_node(graph, "3")

    # :digraph.add_edge(graph, v1, v2)
    # :digraph.add_edge(graph, v1, v3)

    graph
  end

  # def add_answer(graph, vertex, answer) do
  #   node = %{vertex | answer: answer}
  #   :digraph.add_vertex(graph, vertex.id, node)
  #   node
  # end

  def add_node(graph, name, content, class \\ "") do
    vertex = %Vertex{id: name, content: content, class: class}
    :digraph.add_vertex(graph, name, vertex)
    vertex
  end

  def answer(graph, node, answer) do
    new_node_id = gen_id(graph)

    graph
    |> add_child([node], new_node_id, answer, "answer")
  end

  def branch(graph, node) do
    theis_id = gen_id(graph)
    antithesis_id = gen_id(graph, 1)

    {g1, _} =
      graph
      |> add_child([node], theis_id, LlmInterface.gen_thesis(node), "thesis")

    add_child(g1, [node], antithesis_id, LlmInterface.gen_antithesis(node), "antithesis")
  end

  def combine(graph, node1, node2) do
    synthesis_id = gen_id(graph)

    add_child(
      graph,
      [node1, node2],
      synthesis_id,
      LlmInterface.gen_synthesis(node1, node2),
      "syntheis"
    )
  end

  def gen_id(graph, offset \\ 0) do
    v = :digraph.vertices(graph)
    "#{length(v) + 1 + offset}"
  end

  def add_child(graph, parents, child_id, description, class \\ "") do
    # Add nodes using IDs
    node = add_node(graph, child_id, description, class)

    # Add edges using IDs
    Enum.each(parents, fn parent -> :digraph.add_edge(graph, parent.id, child_id) end)

    {graph, node |> Vertex.add_relatives(graph)}
  end
end
