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

  # Deepseek context window 128,000 tokens
  # So for the time being set it to a quarter of the window size.
  def build_context(node, graph, limit \\ 25_000) do
    context =
      collect_parents(graph, node.id)
      |> Enum.map(&add_node_context(&1, graph))
      |> Enum.reverse()
      |> enforce_limit(limit)
      |> Enum.join("\n\n")

    {estimate_tokens(context), context}
  end

  defp enforce_limit([_ | t] = list, limit) do
    cnt = Enum.reduce(list, 0, fn x, acc -> acc + estimate_tokens(x) end)

    if cnt <= limit do
      list
    else
      enforce_limit(t, limit)
    end
  end

  defp estimate_tokens(text) do
    # For example, assume 1 token per 4 characters.
    String.length(text) |> Kernel./(4) |> Float.ceil() |> trunc()
  end

  def add_node_context(node_id, graph) do
    {_, dat} = :digraph.vertex(graph, node_id)
    dat.content
  end

  def collect_parents(graph, vertex) do
    collect_parents(graph, vertex, [])
  end

  # Private recursive function that carries along a list of visited vertices.
  defp collect_parents(graph, vertex, visited) do
    # Get immediate parents that haven't been visited yet.
    parents =
      :digraph.in_neighbours(graph, vertex)
      |> Enum.reject(&(&1 in visited))

    Enum.reduce(parents, [], fn parent, acc ->
      # Mark the parent as visited.
      new_visited = [parent | visited]

      # add the parent and recursively traverse its parents.
      acc ++ [parent] ++ collect_parents(graph, parent, new_visited)
    end)
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
