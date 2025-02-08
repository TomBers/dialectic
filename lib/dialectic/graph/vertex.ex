defmodule Dialectic.Graph.Vertex do
  @derive {Jason.Encoder, only: [:id, :content, :class, :user, :noted_by, :deleted]}
  @valid_classes [
    "thesis",
    "antithesis",
    "syntheis",
    "answer",
    "assumption",
    "premise",
    "conclusion"
  ]
  # Define a custom type for class validation
  # @type class :: "assumption" | "premise" | "conclusion"
  defstruct id: nil,
            content: "",
            class: "",
            user: "",
            parents: [],
            children: [],
            noted_by: [],
            deleted: false

  # Add a function to validate the class
  def validate_class(class) when class in @valid_classes, do: {:ok, class}
  def validate_class(_), do: {:error, "Invalid class. Must be one of: #{inspect(@valid_classes)}"}

  # IMPORTANT - defines fields that should be serialised
  def serialize(vertex) do
    %{
      id: vertex.id,
      content: vertex.content,
      class: vertex.class,
      user: vertex.user,
      noted_by: vertex.noted_by,
      deleted: vertex.deleted
    }
  end

  def deserialize(data) do
    %Dialectic.Graph.Vertex{
      id: data["id"],
      content: data["content"],
      class: data["class"],
      user: data["user"],
      noted_by: data["noted_by"],
      deleted: data["deleted"]
    }
  end

  def add_noted_by(vertex, user) do
    %{vertex | noted_by: [user | vertex.noted_by]}
  end

  def remove_noted_by(vertex, user) do
    %{vertex | noted_by: vertex.noted_by -- [user]}
  end

  def delete_vertex(vertex) do
    %{vertex | deleted: true}
  end

  # ----------------------------

  def changeset(vertex, params \\ %{}) do
    types = %{
      id: :string,
      content: :string,
      class: :string,
      user: :string,
      noted_by: {:array, :string}
    }

    {vertex, types}
    |> Ecto.Changeset.cast(params, Map.keys(types))
  end

  def add_relatives(node, graph) do
    parents = find_parents(graph, node)
    children = find_children(graph, node)
    %{node | parents: parents, children: children}
  end

  # def find_node_by_id(graph_id, id) do
  #   case :digraph.vertex(graph, id) do
  #     # Returns the vertex struct
  #     {_id, vertex} -> vertex
  #     # Return nil if vertex not found
  #     false -> nil
  #   end
  # end

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
    # IO.inspect(graph, label: "Cytoscape graph")
    # Get all vertices and edges from the digraph
    vertices = :digraph.vertices(graph)
    edges = :digraph.edges(graph)

    # Convert vertices to cytoscape nodes format
    nodes =
      Enum.reduce(vertices, [], fn vertex, acc ->
        # Get the vertex label/data from the digraph
        {vid, dat} = :digraph.vertex(graph, vertex)

        # Create cytoscape node format
        case dat.deleted do
          true ->
            acc

          false ->
            acc ++
              [
                %{
                  data: %{
                    id: vid,
                    class: dat.class
                  }
                }
              ]
        end
      end)

    # Convert edges to cytoscape edges format
    edges =
      Enum.reduce(edges, [], fn edge, acc ->
        {_, v1, v2, _} = :digraph.edge(graph, edge)

        # Get vertex data for source and target
        {source_id, s_dat} = :digraph.vertex(graph, v1)
        {target_id, t_dat} = :digraph.vertex(graph, v2)

        # Create edge ID from source and target names
        edge_id = source_id <> "_" <> target_id

        # Create cytoscape edge format
        case !(s_dat.deleted or t_dat.deleted) do
          true ->
            acc ++
              [
                %{
                  data: %{
                    id: edge_id,
                    source: source_id,
                    target: target_id
                  }
                }
              ]

          false ->
            acc
        end
      end)

    # Combine nodes and edges into final format
    nodes ++ edges
  end
end
