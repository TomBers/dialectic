defmodule Dialectic.Graph.Vertex do
  require Logger

  @derive {Jason.Encoder, only: [:id, :content, :class, :user, :noted_by, :deleted]}
  @valid_classes [
    "thesis",
    "antithesis",
    "synthesis",
    "answer",
    "assumption",
    "premise",
    "conclusion",
    "user",
    "question",
    "origin",
    "deepdive"
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

  def deserialize(%Dialectic.Graph.Vertex{} = data), do: data

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
    allowed_parent = Map.get(node, :parent)

    context =
      collect_parents(graph, node.id, allowed_parent)
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
    case :digraph.vertex(graph, node_id) do
      {_id, dat} -> dat.content
      _ -> ""
    end
  end

  def collect_parents(graph, vertex, allowed_parent) do
    # Start BFS from the given vertex's parents
    initial_parents = :digraph.in_neighbours(graph, vertex)
    bfs_parents(graph, initial_parents, MapSet.new(), [], allowed_parent)
  end

  def collect_parents(graph, vertex) do
    # Default behavior: no group scoping when parent is not specified
    collect_parents(graph, vertex, nil)
  end

  # BFS implementation to collect ancestors without duplicates
  # Returns list in BFS order (closest ancestors first)
  defp bfs_parents(_graph, [], _visited, result, _allowed_parent), do: Enum.reverse(result)

  defp bfs_parents(graph, [current_id | rest_queue], visited, result, allowed_parent) do
    if MapSet.member?(visited, current_id) do
      bfs_parents(graph, rest_queue, visited, result, allowed_parent)
    else
      new_visited = MapSet.put(visited, current_id)

      case :digraph.vertex(graph, current_id) do
        {^current_id, label} ->
          parent_group = Map.get(label, :parent)
          is_compound = Map.get(label, :compound, false)
          is_question = Map.get(label, :class) == "question"

          # Check validity
          valid? =
            not is_compound and
              not is_question and
              (is_nil(allowed_parent) or parent_group == allowed_parent)

          if valid? do
            # It's a valid context node. Add to result.
            # And add its parents to queue for further traversal.
            parents = :digraph.in_neighbours(graph, current_id)
            # Append new parents to end of queue for BFS
            new_queue = rest_queue ++ parents

            bfs_parents(graph, new_queue, new_visited, [current_id | result], allowed_parent)
          else
            # Invalid node (stop traversal on this branch)
            bfs_parents(graph, rest_queue, new_visited, result, allowed_parent)
          end

        _ ->
          bfs_parents(graph, rest_queue, new_visited, result, allowed_parent)
      end
    end
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
    parents =
      :digraph.in_edges(graph, vertex.id)
      |> Enum.flat_map(fn edge_id ->
        case :digraph.edge(graph, edge_id) do
          {_edge, parent_id, _child_id, _label} ->
            case :digraph.vertex(graph, parent_id) do
              {_id, v} -> [v]
              _ -> []
            end

          _ ->
            []
        end
      end)

    if parents == [] and :digraph.in_degree(graph, vertex.id) > 0 do
      Logger.warning("Vertex #{vertex.id} has in-degree > 0 but find_parents returned empty list")
    end

    parents
  end

  def find_children(graph, vertex) do
    children =
      :digraph.out_edges(graph, vertex.id)
      |> Enum.flat_map(fn edge_id ->
        case :digraph.edge(graph, edge_id) do
          {_edge, _parent_id, child_id, _label} ->
            case :digraph.vertex(graph, child_id) do
              {_id, v} -> [v]
              _ -> []
            end

          _ ->
            []
        end
      end)

    if children == [] and :digraph.out_degree(graph, vertex.id) > 0 do
      Logger.warning(
        "Vertex #{vertex.id} has out-degree > 0 but find_children returned empty list"
      )
    end

    children
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
        case :digraph.vertex(graph, vertex) do
          {vid, dat} ->
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
                          if Map.get(dat, :compound, false),
                            do: Map.put(m, :compound, true),
                            else: m
                        end)
                    }
                  ]
            end

          _ ->
            acc
        end
      end)

    # Convert edges to cytoscape edges format
    edges =
      Enum.reduce(edges, [], fn edge, acc ->
        with {_, v1, v2, _} <- :digraph.edge(graph, edge),
             {source_id, s_dat} <- :digraph.vertex(graph, v1),
             {target_id, t_dat} <- :digraph.vertex(graph, v2) do
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
        else
          _ -> acc
        end
      end)

    # Combine nodes and edges into final format
    nodes ++ edges
  end
end
