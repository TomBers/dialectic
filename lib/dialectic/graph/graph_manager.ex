defmodule GraphManager do
  use GenServer

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

  def add_vertex(path, vertex) do
    GenServer.call(via_tuple(path), {:add_vertex, vertex})
  end

  def add_edge(path, v1, v2) do
    GenServer.call(via_tuple(path), {:add_edge, v1, v2})
  end

  # Server callbacks
  def init(path) do
    graph = :digraph.new()
    {:ok, {path, graph}}
  end

  def handle_call({:add_vertex, vertex}, _from, {path, graph}) do
    result = :digraph.add_vertex(graph, vertex)
    {:reply, result, {path, graph}}
  end

  def handle_call({:add_edge, v1, v2}, _from, {path, graph}) do
    result = :digraph.add_edge(graph, v1, v2)
    {:reply, result, {path, graph}}
  end
end
