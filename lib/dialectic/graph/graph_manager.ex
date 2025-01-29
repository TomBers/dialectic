defmodule GraphManager do
  alias Dialectic.Graph.Vertex
  alias Dialectic.Graph.Serialise
  use GenServer

  def get_graph(path) do
    case GraphManager.exists?(path) do
      false ->
        {:ok, child} = DynamicSupervisor.start_child(GraphSupervisor, {GraphManager, path})
        child

      true ->
        GenServer.call(via_tuple(path), :get_graph)
    end
  end

  # def get_graph(path) do
  #   case exists?(path) do
  #     true ->
  #       GenServer.call(via_tuple(path), :get_graph)

  #     false ->
  #       start_link(path)
  #       GenServer.call(via_tuple(path), :get_graph)
  #   end
  # end

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
    # graph = :digraph.new()
    graph = Serialise.load_graph(path)
    # TODO - look to read from File
    {:ok, {path, graph}}
  end

  def handle_call(:get_graph, _from, {path, graph}) do
    {:reply, graph, {path, graph}}
  end

  def handle_call({:add_vertex, vertex}, _from, {path, graph}) do
    v = :digraph.vertices(graph)
    v_id = Labeler.label(length(v) + 1)
    vertex = %{vertex | id: v_id}
    :digraph.add_vertex(graph, v_id, vertex)
    {:reply, vertex, {path, graph}}
  end

  def handle_call({:add_edge, vertex, parents}, _from, {path, graph}) do
    Enum.each(parents, fn parent ->
      :digraph.add_edge(graph, parent.id, vertex.id)
    end)

    {:reply, {graph, Vertex.add_relatives(vertex, graph)}, {path, graph}}
  end

  def handle_call({:find_node_by_id, combine_node_id}, _from, {path, graph}) do
    case :digraph.vertex(graph, combine_node_id) do
      {_id, vertex} -> {:reply, {graph, Vertex.add_relatives(vertex, graph)}, {path, graph}}
      false -> {:reply, nil, {path, graph}}
    end
  end

  # In handle_call
  def handle_call({:reset_graph}, _from, {path, graph}) do
    {:reply, graph, {path, :digraph.new()}}
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

  def find_node_by_id(path, combine_node_id) do
    GenServer.call(via_tuple(path), {:find_node_by_id, combine_node_id})
  end

  def add_child(graph_id, parents, description, class, user) do
    node =
      add_node(graph_id, %Vertex{content: description, class: class, user: user})

    add_edges(graph_id, node, parents)
  end
end
