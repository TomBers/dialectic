defmodule Dialectic.Graph.Vertex do
  defstruct id: nil, proposition: nil, answer: nil, parents: [], children: []

  # IMPORTANT - defines fields that should be serialised
  def serialize(vertex) do
    %{id: vertex.id, proposition: vertex.proposition, answer: vertex.answer}
  end

  def deserialize(data) do
    %Dialectic.Graph.Vertex{
      id: data["id"],
      proposition: data["proposition"],
      answer: data["answer"]
    }
  end

  # ----------------------------

  def changeset(vertex, params \\ %{}) do
    types = %{id: :string, proposition: :string, answer: :string}

    {vertex, types}
    |> Ecto.Changeset.cast(params, Map.keys(types))
  end

  def update_vertex(graph, v, new_v) do
    # |> IO.inspect(label: "Update Vertex")
    :digraph.add_vertex(graph, v.id, new_v)
    graph
  end

  def add_relatives(graph, node) do
    parents = find_parents(graph, node)
    children = find_children(graph, node)
    %{node | parents: parents, children: children}
  end

  def find_node_by_id(graph, id) do
    case :digraph.vertex(graph, id) do
      # Returns the vertex struct
      {_id, vertex} -> vertex
      # Return nil if vertex not found
      false -> nil
    end
  end

  def find_parents(graph, vertex) do
    :digraph.in_edges(graph, vertex.id)
    |> Enum.map(fn edge_id ->
      {_edge, parent_id, _child_id, _label} = :digraph.edge(graph, edge_id)
      {_id, vertex} = :digraph.vertex(graph, parent_id)
      vertex
    end)
  end

  def find_children(graph, vertex) do
    :digraph.out_edges(graph, vertex.id)
    |> Enum.map(fn edge_id ->
      {_edge, _parent_id, child_id, _label} = :digraph.edge(graph, edge_id)
      {_id, vertex} = :digraph.vertex(graph, child_id)
      vertex
    end)
  end

  def to_cytoscape_format(graph) do
    # Get all vertices and edges from the digraph
    vertices = :digraph.vertices(graph)
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
