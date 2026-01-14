defmodule GraphManager do
  alias Dialectic.Graph.{Vertex, Serialise, Siblings}

  require Logger

  use GenServer

  def get_graph(path) do
    case exists?(path) do
      false ->
        DynamicSupervisor.start_child(GraphSupervisor, {GraphManager, path})
        GenServer.call(via_tuple(path), :get_graph)

      true ->
        GenServer.call(via_tuple(path), :get_graph)
    end
  end

  # Client API
  def start_link(path) do
    GenServer.start_link(__MODULE__, path, name: via_tuple(path))
  end

  def exists?(path) do
    case :global.whereis_name({:graph, path}) do
      :undefined -> false
      _pid -> true
    end
  end

  def via_tuple(path) do
    {:via, :global, {:graph, path}}
  end

  # Server callbacks
  def init(path) do
    Process.flag(:trap_exit, true)
    # Tag all logs from this server with the graph_id for better tracing
    Logger.metadata(graph_id: path)

    graph_struct =
      Dialectic.DbActions.Graphs.get_graph_by_title(path)

    graph = graph_struct.data |> Serialise.json_to_graph()
    {:ok, {graph_struct, graph}}
  end

  def terminate(reason, {graph_struct, graph}) do
    path = graph_struct.title
    Logger.info("Shutting Down GraphManager for: #{path}, reason: #{inspect(reason)}")

    # Synchronously save graph data before termination
    # This ensures data is persisted even during application shutdown
    try do
      json = Serialise.graph_to_json(graph)
      # Use synchronous save for immediate persistence
      case Dialectic.DbActions.Graphs.save_graph(path, json) do
        {:ok, _} ->
          Logger.info("Successfully saved graph #{path} during shutdown")

        {:error, reason} ->
          Logger.error("Failed to save graph #{path} during shutdown: #{inspect(reason)}")
      end
    rescue
      error ->
        Logger.error(
          "Exception saving graph #{path} during shutdown: #{Exception.format(:error, error, __STACKTRACE__)}"
        )
    end

    :ok
  end

  def save_graph_to_db(path, graph) do
    Logger.info("Queuing Save: " <> path)
    json = Serialise.graph_to_json(graph)
    Dialectic.DbActions.DbWorker.save_snapshot(path, json)
  end

  def handle_call(:get_graph, _from, {graph_struct, graph}) do
    {:reply, {graph_struct, graph}, {graph_struct, graph}}
  end

  def handle_call({:add_vertex, vertex}, _from, {graph_struct, graph}) do
    existing_ids =
      :digraph.vertices(graph)
      |> MapSet.new()

    # Determine the next numeric ID as count(existing) + 1, then increment until unused
    next_int = MapSet.size(existing_ids) + 1

    v_id =
      Stream.iterate(next_int, &(&1 + 1))
      |> Enum.find(fn n ->
        id = Integer.to_string(n)
        not MapSet.member?(existing_ids, id)
      end)
      |> Integer.to_string()

    vertex = %{vertex | id: v_id}
    :digraph.add_vertex(graph, v_id, vertex)
    {:reply, vertex, {graph_struct, graph}}
  end

  def handle_call({:add_edge, vertex, parents}, _from, {graph_struct, graph}) do
    Enum.each(parents, fn parent ->
      :digraph.add_edge(graph, parent.id, vertex.id)
    end)

    {:reply, Vertex.add_relatives(vertex, graph), {graph_struct, graph}}
  end

  def handle_call({:find_node_by_id, combine_node_id}, _from, {graph_struct, graph}) do
    case :digraph.vertex(graph, combine_node_id) do
      {_id, vertex} ->
        {:reply, Vertex.add_relatives(vertex, graph), {graph_struct, graph}}

      false ->
        {:reply, nil, {graph_struct, graph}}
    end
  end

  def handle_call({:build_context, node, limit}, _from, {graph_struct, graph}) do
    {:reply, Vertex.build_context(node, graph, limit), {graph_struct, graph}}
  end

  # In handle_call
  def handle_call({:reset_graph}, _from, {graph_struct, _graph}) do
    {:reply, :digraph.new(), {graph_struct, :digraph.new()}}
  end

  # -------- Safe query handle_call implementations --------

  def handle_call({:vertex_label, node_id}, _from, {graph_struct, graph}) do
    reply =
      case :digraph.vertex(graph, node_id) do
        {^node_id, v} -> v
        _ -> nil
      end

    {:reply, reply, {graph_struct, graph}}
  end

  def handle_call({:out_neighbours, node_id}, _from, {graph_struct, graph}) do
    neighbours =
      try do
        :digraph.out_neighbours(graph, node_id)
      rescue
        e ->
          log_digraph_error(:out_neighbours, node_id, e, __STACKTRACE__)
          []
      end

    {:reply, neighbours, {graph_struct, graph}}
  end

  def handle_call({:in_neighbours, node_id}, _from, {graph_struct, graph}) do
    neighbours =
      try do
        :digraph.in_neighbours(graph, node_id)
      rescue
        e ->
          log_digraph_error(:in_neighbours, node_id, e, __STACKTRACE__)
          []
      end

    {:reply, neighbours, {graph_struct, graph}}
  end

  def handle_call(:vertices, _from, {graph_struct, graph}) do
    verts =
      try do
        :digraph.vertices(graph)
      rescue
        e ->
          log_digraph_error(:vertices, :all, e, __STACKTRACE__)
          []
      end

    {:reply, verts, {graph_struct, graph}}
  end

  def handle_call({:has_child_with_class, node_id, class}, _from, {graph_struct, graph}) do
    has_child =
      try do
        :digraph.out_neighbours(graph, node_id)
        |> Enum.any?(fn cid ->
          case :digraph.vertex(graph, cid) do
            {^cid, v} when is_map(v) -> Map.get(v, :class) == class
            _ -> false
          end
        end)
      rescue
        _ -> false
      end

    {:reply, has_child, {graph_struct, graph}}
  end

  def handle_call(:format_graph_json, _from, {graph_struct, graph}) do
    json =
      try do
        graph |> Vertex.to_cytoscape_format() |> Jason.encode!()
      rescue
        _ -> "[]"
      end

    {:reply, json, {graph_struct, graph}}
  end

  def handle_call({:save_graph, path}, _from, {graph_struct, graph}) do
    {:reply, save_graph_to_db(path, graph), {graph_struct, graph}}
  end

  def handle_call({:update_node, {node_id, data}}, _from, {graph_struct, graph}) do
    case :digraph.vertex(graph, node_id) do
      {_id, vertex} ->
        safe = to_string(data)
        updated_vertex = %{vertex | content: vertex.content <> safe}
        :digraph.add_vertex(graph, node_id, updated_vertex)
        {:reply, updated_vertex, {graph_struct, graph}}

      false ->
        {:reply, nil, {graph_struct, graph}}
    end
  end

  def handle_call({:set_node_content, {node_id, content}}, _from, {graph_struct, graph}) do
    case :digraph.vertex(graph, node_id) do
      {_id, vertex} ->
        updated_vertex = %{vertex | content: to_string(content)}
        :digraph.add_vertex(graph, node_id, updated_vertex)
        {:reply, updated_vertex, {graph_struct, graph}}

      false ->
        {:reply, nil, {graph_struct, graph}}
    end
  end

  def handle_call({:toggle_graph_locked}, _from, {graph_struct, graph}) do
    updated_graph_struct = Dialectic.DbActions.Graphs.toggle_graph_locked(graph_struct)
    {:reply, updated_graph_struct, {updated_graph_struct, graph}}
  end

  def handle_call({:toggle_graph_public}, _from, {graph_struct, graph}) do
    updated_graph_struct = Dialectic.DbActions.Graphs.toggle_graph_public(graph_struct)
    {:reply, updated_graph_struct, {updated_graph_struct, graph}}
  end

  def handle_call({:change_noted_by, {node_id, user, change_fn}}, _from, {graph_struct, graph}) do
    case :digraph.vertex(graph, node_id) do
      {_id, vertex} ->
        updated_vertex = change_fn.(vertex, user)
        :digraph.add_vertex(graph, node_id, updated_vertex)
        {:reply, Vertex.add_relatives(updated_vertex, graph), {graph_struct, graph}}

      false ->
        {:reply, nil, {graph_struct, graph}}
    end
  end

  def handle_call({:delete_node, node_id}, _from, {graph_struct, graph}) do
    case :digraph.vertex(graph, node_id) do
      {_id, vertex} ->
        updated_vertex = Vertex.add_relatives(vertex, graph) |> Vertex.delete_vertex()
        :digraph.add_vertex(graph, node_id, updated_vertex)
        {:reply, List.first(updated_vertex.parents), {graph_struct, graph}}

      false ->
        {:reply, nil, {graph_struct, graph}}
    end
  end

  def handle_call({:path_to_node, node}, _, {graph_struct, graph}) do
    # Build a linear chain from the current node up to the root by
    # repeatedly following the first immediate parent. This avoids
    # arbitrary ordering from sets and produces a deterministic path.
    build_chain =
      fn build_chain, current, acc ->
        case :digraph.in_neighbours(graph, current.id) do
          [parent_id | _] ->
            case :digraph.vertex(graph, parent_id) do
              {^parent_id, parent_vertex} ->
                build_chain.(build_chain, parent_vertex, acc ++ [parent_vertex])

              _ ->
                acc
            end

          [] ->
            acc
        end
      end

    chain = build_chain.(build_chain, node, [node])

    {:reply, chain, {graph_struct, graph}}
  end

  def handle_call({:move, {node_or_id, direction}}, _, {graph_struct, graph}) do
    node_id = if is_map(node_or_id), do: node_or_id.id, else: node_or_id

    case :digraph.vertex(graph, node_id) do
      {^node_id, raw_vertex} ->
        # Use authoritative state from graph for navigation
        current_node = Vertex.add_relatives(raw_vertex, graph)

        next_node =
          case direction do
            "up" ->
              Siblings.up(current_node)

            "down" ->
              Siblings.down(current_node)

            "left" ->
              Siblings.left(current_node, graph)

            "right" ->
              Siblings.right(current_node, graph)
          end

        {:reply, Vertex.add_relatives(next_node, graph), {graph_struct, graph}}

      false ->
        {:reply, nil, {graph_struct, graph}}
    end
  end

  def handle_call({:create_group, {group_title, child_ids}}, _, {graph_struct, graph}) do
    try do
      updated_graph = Vertex.add_group(graph, group_title, child_ids)
      {:reply, updated_graph, {graph_struct, updated_graph}}
    rescue
      e ->
        Logger.error("create_group failed",
          group_title: group_title,
          child_ids: child_ids
        )

        reraise e, __STACKTRACE__
    end
  end

  def handle_call({:change_parent, {node_id, parent_id}}, _, {graph_struct, graph}) do
    updated_graph =
      Vertex.change_parent(graph, node_id, parent_id)

    {:reply, updated_graph, {graph_struct, updated_graph}}
  end

  def handle_call({:finalize_node, node_id}, _from, {graph_struct, graph}) do
    case :digraph.vertex(graph, node_id) do
      {_id, vertex} ->
        {:reply, Vertex.add_relatives(vertex, graph), {graph_struct, graph}}

      false ->
        {:reply, nil, {graph_struct, graph}}
    end
  end

  def handle_call(:find_leaf_nodes, _, {graph_struct, graph}) do
    {:reply, Vertex.find_leaf_nodes(graph), {graph_struct, graph}}
  end

  # -------- Safe public query APIs (avoid exposing raw digraph ETS handles) --------

  # Returns the vertex label (payload map) for a node_id or nil if not found
  def vertex_label(path, node_id) do
    GenServer.call(via_tuple(path), {:vertex_label, node_id})
  end

  # Returns list of out-neighbour ids for a given node_id
  def out_neighbours(path, node_id) do
    GenServer.call(via_tuple(path), {:out_neighbours, node_id})
  end

  # Returns list of in-neighbour ids for a given node_id
  def in_neighbours(path, node_id) do
    GenServer.call(via_tuple(path), {:in_neighbours, node_id})
  end

  # Returns list of all vertex ids in the graph
  def vertices(path) do
    GenServer.call(via_tuple(path), :vertices)
  end

  # Convenience: does node have a child with the given class?
  def has_child_with_class(path, node_id, class) do
    GenServer.call(via_tuple(path), {:has_child_with_class, node_id, class})
  end

  # Server-side formatting of the graph as JSON for the UI (Cytoscape format)
  def format_graph_json(path) do
    GenServer.call(via_tuple(path), :format_graph_json)
  end

  # Helper telemetry/logging for digraph errors
  defp telemetry_error(op, tags) do
    :telemetry.execute([:dialectic, :graph, :error], %{count: 1}, Map.merge(%{op: op}, tags))
  end

  defp log_digraph_error(op, node_id, error, stack) do
    telemetry_error(op, %{node_id: node_id})

    Logger.error("""
    digraph error
    op=#{inspect(op)} node_id=#{inspect(node_id)}
    error=#{Exception.format(:error, error, stack)}
    """)
  end

  # Client API
  def reset_graph(path) do
    if GraphManager.exists?(path) do
      GenServer.call(via_tuple(path), {:reset_graph})
    end

    :ok
  end

  def add_node(path, vertex) do
    GenServer.call(via_tuple(path), {:add_vertex, vertex})
  end

  def add_edges(path, node, parents) do
    GenServer.call(via_tuple(path), {:add_edge, node, parents})
  end

  def find_node_by_id(path, node_id) do
    GenServer.call(via_tuple(path), {:find_node_by_id, node_id})
  end

  def add_child(graph_id, parents, llm_fn, class, user, opts \\ []) do
    save? = Keyword.get(opts, :save, true)

    content =
      case class do
        c when c in ["user", "question"] ->
          val = llm_fn.(class)
          if is_binary(val), do: val, else: ""

        _ ->
          ""
      end

    # Check if any parent has a parent field (group membership) set
    parent_group =
      parents
      |> Enum.find_value(nil, fn parent ->
        case vertex_label(graph_id, parent.id) do
          %{} = v -> Map.get(v, :parent)
          _ -> nil
        end
      end)

    node =
      add_node(graph_id, %Vertex{content: content, class: class, user: user, parent: parent_group})

    # Stream response to the Node using supervised task
    Task.Supervisor.start_child(Dialectic.TaskSupervisor, fn -> llm_fn.(node) end)

    result = add_edges(graph_id, node, parents)

    if save? do
      save_graph(graph_id)
    end

    result
  end

  def update_vertex(path, node_id, data) do
    GenServer.call(via_tuple(path), {:update_node, {node_id, data}})
  end

  def set_node_content(path, node_id, content) do
    GenServer.call(via_tuple(path), {:set_node_content, {node_id, content}})
  end

  def finalize_node_content(path, node_id) do
    GenServer.call(via_tuple(path), {:finalize_node, node_id})
  end

  def toggle_graph_locked(path) do
    GenServer.call(via_tuple(path), {:toggle_graph_locked})
  end

  def toggle_graph_public(path) do
    GenServer.call(via_tuple(path), {:toggle_graph_public})
  end

  def change_noted_by(path, node_id, user, change_fn) do
    GenServer.call(via_tuple(path), {:change_noted_by, {node_id, user, change_fn}})
  end

  def move(path, node, direction) do
    GenServer.call(via_tuple(path), {:move, {node, direction}})
  end

  def delete_node(path, node_id) do
    GenServer.call(via_tuple(path), {:delete_node, node_id})
  end

  def build_context(path, node, limit \\ 5000) do
    GenServer.call(via_tuple(path), {:build_context, node, limit})
  end

  def path_to_node(path, node) do
    GenServer.call(via_tuple(path), {:path_to_node, node})
  end

  def save_graph(path) do
    GenServer.call(via_tuple(path), {:save_graph, path})
  end

  def create_group(path, group_title, child_ids) do
    GenServer.call(via_tuple(path), {:create_group, {group_title, child_ids}})
  end

  def set_parent(path, node_id, parent_id) do
    GenServer.call(via_tuple(path), {:change_parent, {node_id, parent_id}})
  end

  def remove_parent(path, node_id) do
    GenServer.call(via_tuple(path), {:change_parent, {node_id, nil}})
  end

  def find_leaf_nodes(path) do
    GenServer.call(via_tuple(path), :find_leaf_nodes)
  end

  # Ensure a "Main" compound group exists and contains all top-level nodes.
  # Operates via GenServer calls only; does not return or rely on digraph handles.
  def ensure_main_group(path) do
    case vertex_label(path, "Main") do
      %{} ->
        :ok

      _ ->
        child_ids =
          vertices(path)
          |> Enum.filter(fn vid ->
            case vertex_label(path, vid) do
              %{} = v ->
                Map.get(v, :compound, false) != true and is_nil(Map.get(v, :parent))

              _ ->
                false
            end
          end)

        # Create the group and assign children (safe server-side mutation)
        _ = create_group(path, "Main", child_ids)
        # Persist immediately so the new group isn't lost until a later save
        Dialectic.DbActions.DbWorker.save_graph(path)
        :ok
    end
  end

  # Returns a robust "best" node to render:
  # - try desired_id
  # - else try "1"
  # - else first non-deleted vertex
  # - else nil
  def best_node(path, desired_id) do
    with nil <- find_node_by_id(path, desired_id),
         nil <- find_node_by_id(path, "1") do
      fallback_id =
        vertices(path)
        |> Enum.find_value(fn vid ->
          case vertex_label(path, vid) do
            %{} = v ->
              if not Map.get(v, :deleted, false), do: v.id, else: nil

            _ ->
              nil
          end
        end)

      if is_binary(fallback_id) do
        find_node_by_id(path, fallback_id)
      else
        nil
      end
    else
      node -> node
    end
  end
end
