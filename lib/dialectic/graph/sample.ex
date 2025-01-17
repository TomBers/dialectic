defmodule Dialectic.Graph.Sample do
  alias Dialectic.Graph.Vertex

  # To test - Graph A -> B, A -> C, B -> D and C -> D
  def run do
    graph = :digraph.new()

    v1 = add_node(graph, "A")
    v2 = add_node(graph, "B")
    v3 = add_node(graph, "C")

    :digraph.add_edge(graph, v1, v2)
    :digraph.add_edge(graph, v1, v3)

    graph
  end

  def add_node(graph, name) do
    add_node(graph, name, "#{name} description")
  end

  def add_node(graph, name, description) do
    vertex = %Vertex{id: name, description: description}
    :digraph.add_vertex(graph, name, vertex)
  end

  def add_child(graph, parent) do
    thesis_id = "#{parent.id}_Thesis"
    antithesis_id = "#{parent.id}_Antithesis"

    # Add nodes using IDs
    add_node(graph, thesis_id)
    add_node(graph, antithesis_id)

    # Add edges using IDs
    :digraph.add_edge(graph, parent.id, thesis_id)
    :digraph.add_edge(graph, parent.id, antithesis_id)

    graph
  end
end
