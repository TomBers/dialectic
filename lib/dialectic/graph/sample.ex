defmodule Dialectic.Graph.Sample do
  alias Dialectic.Graph.Vertex

  # To test - Graph A -> B, A -> C, B -> D and C -> D
  def run do
    graph = :digraph.new()
    a = %Vertex{name: "A", description: "A description"}
    b = %Vertex{name: "Bb", description: "B description"}
    c = %Vertex{name: "Cc", description: "C description"}
    # d = %Vertex{name: "Dd"}

    v1 = :digraph.add_vertex(graph, a)
    v2 = :digraph.add_vertex(graph, b)
    v3 = :digraph.add_vertex(graph, c)
    # v4 = :digraph.add_vertex(graph, d)

    :digraph.add_edge(graph, v1, v2)
    :digraph.add_edge(graph, v1, v3)
    # :digraph.add_edge(graph, v2, v4)
    # :digraph.add_edge(graph, v3, v4)
    # IO.inspect(graph, label: "Graph")

    graph
  end

  def add_child(graph, parent) do
    thesis = %Vertex{name: "#{parent.name}_Thesis"}
    theis_child = :digraph.add_vertex(graph, thesis)

    antithesis = %Vertex{name: "#{parent.name}_Antithesis"}
    antithesis_child = :digraph.add_vertex(graph, antithesis)
    :digraph.add_edge(graph, parent, theis_child)
    :digraph.add_edge(graph, parent, antithesis_child)
    graph
  end
end
