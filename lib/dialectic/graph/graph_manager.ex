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
    case Registry.lookup(GraphRegistry, path) do
      [] -> false
      _ -> true
    end
  end

  def via_tuple(path) do
    {:via, Registry, {GraphRegistry, path}}
  end

  # Server callbacks
  def init(path) do
    Process.flag(:trap_exit, true)

    graph_struct =
      Dialectic.DbActions.Graphs.get_graph_by_title(path)

    graph = graph_struct.data |> Serialise.json_to_graph()
    {:ok, {graph_struct, graph}}
  end

  def terminate(_reason, {graph_struct, graph}) do
    path = graph_struct.title
    Logger.info("Shutting Down: " <> path)
    save_graph_to_db(path, graph)
    :ok
  end

  def save_graph_to_db(path, graph) do
    Logger.info("Saving: " <> path)
    json = Serialise.graph_to_json(graph)
    Dialectic.DbActions.Graphs.save_graph(path, json)
  end

  def handle_call(:get_graph, _from, {graph_struct, graph}) do
    {:reply, {graph_struct, graph}, {graph_struct, graph}}
  end

  def handle_call({:add_vertex, vertex}, _from, {graph_struct, graph}) do
    existing_ids =
      :digraph.vertices(graph)
      |> MapSet.new()

    candidate = Integer.to_string(System.unique_integer([:positive, :monotonic]))

    v_id =
      if MapSet.member?(existing_ids, candidate) do
        "n-" <> Ecto.UUID.generate()
      else
        candidate
      end

    vertex = %{vertex | id: v_id}
    :digraph.add_vertex(graph, v_id, vertex)
    {:reply, vertex, {graph_struct, graph}}
  end

  def handle_call({:add_edge, vertex, parents}, _from, {graph_struct, graph}) do
    Enum.each(parents, fn parent ->
      :digraph.add_edge(graph, parent.id, vertex.id)
    end)

    {:reply, {graph, Vertex.add_relatives(vertex, graph)}, {graph_struct, graph}}
  end

  def handle_call({:find_node_by_id, combine_node_id}, _from, {graph_struct, graph}) do
    case :digraph.vertex(graph, combine_node_id) do
      {_id, vertex} ->
        {:reply, {graph, Vertex.add_relatives(vertex, graph)}, {graph_struct, graph}}

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

  def handle_call({:save_graph, path}, _from, {graph_struct, graph}) do
    {:reply, save_graph_to_db(path, graph), {graph_struct, graph}}
  end

  def handle_call({:update_node, {node_id, data}}, _from, {graph_struct, graph}) do
    case :digraph.vertex(graph, node_id) do
      {_id, vertex} ->
        updated_vertex = %{vertex | content: vertex.content <> data}
        :digraph.add_vertex(graph, node_id, updated_vertex)
        {:reply, Vertex.add_relatives(updated_vertex, graph), {graph_struct, graph}}

      false ->
        {:reply, nil, {graph_struct, graph}}
    end
  end

  def handle_call({:toggle_graph_locked}, _from, {graph_struct, graph}) do
    updated_graph_struct = Dialectic.DbActions.Graphs.toggle_graph_locked(graph_struct)
    {:reply, updated_graph_struct, {updated_graph_struct, graph}}
  end

  def handle_call({:change_noted_by, {node_id, user, change_fn}}, _from, {graph_struct, graph}) do
    case :digraph.vertex(graph, node_id) do
      {_id, vertex} ->
        updated_vertex = change_fn.(vertex, user)
        :digraph.add_vertex(graph, node_id, updated_vertex)
        {:reply, {graph, Vertex.add_relatives(updated_vertex, graph)}, {graph_struct, graph}}

      false ->
        {:reply, nil, {graph_struct, graph}}
    end
  end

  def handle_call({:delete_node, node_id}, _from, {graph_struct, graph}) do
    case :digraph.vertex(graph, node_id) do
      {_id, vertex} ->
        updated_vertex = Vertex.add_relatives(vertex, graph) |> Vertex.delete_vertex()
        :digraph.add_vertex(graph, node_id, updated_vertex)
        {:reply, {graph, List.first(updated_vertex.parents)}, {graph_struct, graph}}

      false ->
        {:reply, nil, {graph_struct, graph}}
    end
  end

  def handle_call({:path_to_node, node}, _, {graph_struct, graph}) do
    parents =
      Vertex.collect_parents(graph, node.id)
      |> MapSet.new()
      |> Enum.map(fn node_index ->
        case :digraph.vertex(graph, node_index) do
          {_id, vertex} -> vertex
          false -> nil
        end
      end)
      |> Enum.reverse()

    {:reply, [node] ++ parents, {graph_struct, graph}}
  end

  def handle_call({:move, {node, direction}}, _, {graph_struct, graph}) do
    updated_vertex =
      case direction do
        "up" ->
          Siblings.up(node)

        "down" ->
          Siblings.down(node)

        "left" ->
          Siblings.left(node, graph)

        "right" ->
          Siblings.right(node, graph)
      end

    {:reply, {graph, Vertex.add_relatives(updated_vertex, graph)}, {graph_struct, graph}}
  end

  def handle_call({:create_group, {group_title, child_ids}}, _, {graph_struct, graph}) do
    updated_graph =
      Vertex.add_group(graph, group_title, child_ids)

    {:reply, updated_graph, {graph_struct, updated_graph}}
  end

  def handle_call({:change_parent, {node_id, parent_id}}, _, {graph_struct, graph}) do
    updated_graph =
      Vertex.change_parent(graph, node_id, parent_id)

    {:reply, updated_graph, {graph_struct, updated_graph}}
  end

  def handle_call(:find_leaf_nodes, _, {graph_struct, graph}) do
    {:reply, Vertex.find_leaf_nodes(graph), {graph_struct, graph}}
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

  def add_child(graph_id, parents, llm_fn, class, user) do
    content =
      case class do
        "user" ->
          llm_fn.(class)

        _ ->
          ""
      end

    # Check if any parent has a parent field (group membership) set
    parent_group =
      parents
      |> Enum.find_value(nil, fn parent ->
        case :digraph.vertex(get_graph(graph_id) |> elem(1), parent.id) do
          {_id, vertex} -> Map.get(vertex, :parent)
          _ -> nil
        end
      end)

    node =
      add_node(graph_id, %Vertex{content: content, class: class, user: user, parent: parent_group})

    # Stream response to the Node
    spawn(fn -> llm_fn.(node) end)

    add_edges(graph_id, node, parents)
  end

  def update_vertex(path, node_id, data) do
    GenServer.call(via_tuple(path), {:update_node, {node_id, data}})
  end

  def toggle_graph_locked(path) do
    GenServer.call(via_tuple(path), {:toggle_graph_locked})
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
end
