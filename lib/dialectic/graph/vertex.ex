defmodule Dialectic.Graph.Vertex do
  defstruct name: nil, description: nil, data: nil

  def to_cytoscape_format(graph) do
    # Get all vertices and edges from the digraph
    vertices = :digraph.vertices(graph)
    # IO.inspect(vertices, label: "Vertices")
    edges = :digraph.edges(graph)

    # Convert vertices to cytoscape nodes format
    nodes =
      Enum.map(vertices, fn vertex ->
        # Get the vertex label/data from the digraph
        vertex_data = :digraph.vertex(graph, vertex) |> elem(0)

        # Create cytoscape node format
        %{
          data: %{
            id: vertex_data.name
          }
        }
      end)

    # Convert edges to cytoscape edges format
    edges =
      Enum.map(edges, fn edge ->
        {_, v1, v2, _} = :digraph.edge(graph, edge)

        # Get vertex data for source and target
        source_data = :digraph.vertex(graph, v1) |> elem(0)
        target_data = :digraph.vertex(graph, v2) |> elem(0)

        # Create edge ID from source and target names
        edge_id = source_data.name <> target_data.name

        # Create cytoscape edge format
        %{
          data: %{
            id: edge_id,
            source: source_data.name,
            target: target_data.name
          }
        }
      end)

    # Combine nodes and edges into final format
    nodes ++ edges
  end
end
