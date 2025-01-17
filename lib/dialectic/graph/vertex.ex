defmodule Dialectic.Graph.Vertex do
  alias Dialectic.Graph.Vertex
  defstruct id: nil, description: nil, data: nil

  def changeset(vertex, params \\ %{}) do
    types = %{id: :string, description: :string, data: :integer}

    {vertex, types}
    |> Ecto.Changeset.cast(params, Map.keys(types))
  end

  def update_vertex(graph, v, new_v) do
    :digraph.add_vertex(graph, v.id, new_v) |> IO.inspect(label: "Update Vertex")
    graph
  end

  def find_node_by_id(graph, id) do
    case :digraph.vertex(graph, id) do
      # Returns the vertex struct
      {_id, vertex} -> vertex
      # Return nil if vertex not found
      false -> nil
    end
  end

  def to_cytoscape_format(graph) do
    # Get all vertices and edges from the digraph
    vertices = :digraph.vertices(graph)
    # IO.inspect(vertices, label: "Vertices")
    edges = :digraph.edges(graph)

    # Convert vertices to cytoscape nodes format
    nodes =
      Enum.map(vertices, fn vertex ->
        # Get the vertex label/data from the digraph
        {vertex_data, _} = :digraph.vertex(graph, vertex)

        # Create cytoscape node format
        %{
          data: %{
            id: vertex_data
          }
        }
      end)

    # Convert edges to cytoscape edges format
    edges =
      Enum.map(edges, fn edge ->
        {_, v1, v2, _} = :digraph.edge(graph, edge)

        # Get vertex data for source and target
        {source_data, _} = :digraph.vertex(graph, v1)
        {target_data, _} = :digraph.vertex(graph, v2)

        # Create edge ID from source and target names
        edge_id = source_data <> target_data

        # Create cytoscape edge format
        %{
          data: %{
            id: edge_id,
            source: source_data,
            target: target_data
          }
        }
      end)

    # Combine nodes and edges into final format
    nodes ++ edges
  end
end
