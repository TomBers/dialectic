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
    vertex = %Vertex{name: name, description: description}
    :digraph.add_vertex(graph, vertex)
  end

  def add_child(graph, parent) do
    theis_child = add_node(graph, "#{parent.name}_Thesis")
    antithesis_child = add_node(graph, "#{parent.name}_Antithesis")

    :digraph.add_edge(graph, parent, theis_child)
    :digraph.add_edge(graph, parent, antithesis_child)
    graph
  end
end
