defmodule Dialectic.Graph.Vertex do
  @derive {Jason.Encoder, only: [:id, :content, :class, :user, :noted_by, :deleted]}
  @valid_classes [
    "thesis",
    "antithesis",
    "syntheis",
    "answer",
    "assumption",
    "premise",
    "conclusion",
    "user"
  ]
  # Define a custom type for class validation
  # @type class :: "assumption" | "premise" | "conclusion"
  defstruct id: nil,
            content: "",
            class: "",
            user: "",
            parent: nil,
            parents: [],
            children: [],
            noted_by: [],
            deleted: false,
            compound: false

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
      parent: vertex.parent,
      noted_by: vertex.noted_by,
      deleted: vertex.deleted,
      compound: vertex.compound
    }
  end

  def deserialize(data) do
    %Dialectic.Graph.Vertex{
      id: data["id"],
      content: data["content"],
      class: data["class"],
      user: data["user"],
      parent: data["parent"],
      noted_by: data["noted_by"],
      deleted: data["deleted"],
      compound: data["compound"]
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

  def build_context(node, graph, limit) do
    context =
      collect_parents(graph, node.id)
      |> Enum.map(&add_node_context(&1, graph))
      |> Enum.reverse()
      |> enforce_limit(limit)
      |> Enum.join("\n\n")

    context
  end

  defp enforce_limit([], _limit), do: []

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

  def find_leaf_nodes(graph) do
    :digraph.vertices(graph)
    |> Enum.filter(fn vertex ->
      :digraph.out_degree(graph, vertex) == 0
    end)
    |> Enum.map(fn node_id ->
      {_, dat} = :digraph.vertex(graph, node_id)
      add_relatives(dat, graph)
    end)
    |> Enum.reject(fn node ->
      node.compound == true
    end)
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

  @doc """
  Adds a *group* vertex whose ID **is the title string itself**
  and tags every child vertex with `parent: title`.

  Returns the same `:digraph.graph()` handle (mutated in place).
  """
  @spec add_group(:digraph.graph(), String.t(), [String.t()]) :: :digraph.graph()
  def add_group(graph, title, child_ids) do
    # 1.  create the new compound‑node vertex
    :digraph.add_vertex(
      graph,
      # vertex ID == title
      title,
      # Cytoscape‑friendly payload
      %Dialectic.Graph.Vertex{id: title, compound: true}
    )

    # 2.  update each child so Cytoscape knows its parent
    Enum.each(child_ids, fn id ->
      case :digraph.vertex(graph, id) do
        false ->
          # skip unknown IDs (or raise)
          :ok

        {^id, old_label} ->
          new_label = Map.put(old_label, :parent, title)
          # replace label in place
          :digraph.add_vertex(graph, id, new_label)
      end
    end)

    # ← same reference, now mutated
    graph
  end

  def change_parent(graph, node_id, parent_id) do
    case :digraph.vertex(graph, node_id) do
      false ->
        # Skip unknown IDs (or raise)
        :ok

      {^node_id, old_label} ->
        # Get the old parent ID before changing
        old_parent_id = Map.get(old_label, :parent)

        # Assign the new parent
        new_label = Map.put(old_label, :parent, parent_id)
        :digraph.add_vertex(graph, node_id, new_label)

        # Only if we are removing node from group
        if parent_id == nil do
          check_and_remove_if_empty(graph, old_parent_id)
        end

        graph
    end
  end

  # Simpler helper function to check if a compound node is empty and remove if needed
  def check_and_remove_if_empty(graph, parent_id) do
    case :digraph.vertex(graph, parent_id) do
      false ->
        :ok

      {^parent_id, parent_label} ->
        # Only proceed if this is a compound node
        if Map.get(parent_label, :compound, false) do
          # Check if any node has this parent
          has_children =
            Enum.any?(:digraph.vertices(graph), fn vertex_id ->
              vertex_id != parent_id and
                case :digraph.vertex(graph, vertex_id) do
                  {^vertex_id, label} -> Map.get(label, :parent) == parent_id
                  _ -> false
                end
            end)

          # If no children found and it's a compound node, remove it
          if not has_children do
            :digraph.del_vertex(graph, parent_id)
          end
        end
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
                  classes: dat.class,
                  data:
                    %{
                      id: vid,
                      parent: Map.get(dat, :parent, ""),
                      content: dat.content
                    }
                    |> then(fn m ->
                      if Map.get(dat, :compound, false), do: Map.put(m, :compound, true), else: m
                    end)
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
