defmodule Dialectic.Graph.Sample do
  alias Dialectic.Graph.Vertex

  # To test - Graph A -> B, A -> C, B -> D and C -> D
  def run do
    graph = :digraph.new()

    v1 = add_node(graph, "A")
    v2 = add_node(graph, "B")
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

  def add_child(graph, parent, child_id, description) do
    # Add nodes using IDs
    add_node(graph, child_id, description)

    # Add edges using IDs
    :digraph.add_edge(graph, parent.id, child_id)

    graph
  end
end
