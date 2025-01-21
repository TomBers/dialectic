defmodule Dialectic.Graph.Sample do
  alias Dialectic.Graph.Vertex
  alias Dialectic.Responses.LlmInterface

  # To test - Graph A -> B, A -> C, B -> D and C -> D
  def run do
    graph = :digraph.new()

    v1 = add_node(graph, "1")
    v2 = add_node(graph, "2")
    # v3 = add_node(graph, "C")

    :digraph.add_edge(graph, v1, v2)
    # :digraph.add_edge(graph, v1, v3)

    graph
  end

  def add_node(graph, name) do
    add_node(graph, name, Dialectic.Responses.LlmInterface.gen_response("BOB"))
  end

  def add_answer(graph, vertex, answer) do
    node = %{vertex | answer: answer}
    :digraph.add_vertex(graph, vertex.id, node)
    node
  end

  def add_node(graph, name, description) do
    vertex = %Vertex{id: name, proposition: description}
    :digraph.add_vertex(graph, name, vertex)
  end

  def branch(graph, node) do
    v = :digraph.vertices(graph)
    theis_id = "#{length(v) + 1}"
    antithesis_id = "#{length(v) + 2}"

    graph
    |> add_child(node, theis_id, LlmInterface.gen_response(node.proposition))
    |> add_child(node, antithesis_id, LlmInterface.gen_response(node.proposition))
  end

  def combine(graph, node1, node2) do
    synthesis_id = "#{node1.id}_#{node2.id}_synthesis"

    promposition = "#{node1.proposition} and #{node2.proposition}"

    add_node(graph, synthesis_id, LlmInterface.gen_response(promposition))
    :digraph.add_edge(graph, node1.id, synthesis_id)
    :digraph.add_edge(graph, node2.id, synthesis_id)

    {synthesis_id, graph}
  end

  def add_child(graph, parent, child_id, description) do
    # Add nodes using IDs
    add_node(graph, child_id, description)

    # Add edges using IDs
    :digraph.add_edge(graph, parent.id, child_id)

    graph
  end
end
