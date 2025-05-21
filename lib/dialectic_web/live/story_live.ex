defmodule DialecticWeb.StoryLive do
  use DialecticWeb, :live_view

  def mount(%{"graph_name" => graph_id_uri}, _session, socket) do
    graph_id = URI.decode(graph_id_uri)

    leaf_nodes = GraphManager.find_leaf_nodes(graph_id)

    ln = List.first(leaf_nodes)

    path =
      GraphManager.path_to_node(graph_id, ln)
      |> Enum.reverse()

    {:ok, assign(socket, graph_id: graph_id, path: path, leaf_nodes: leaf_nodes)}
  end

  def handle_event("next", _, socket) do
    ln = List.last(socket.assigns.leaf_nodes)
    return_path(socket, ln)
  end

  def handle_event("previous", _, socket) do
    ln = List.first(socket.assigns.leaf_nodes)
    return_path(socket, ln)
  end

  defp return_path(socket, leaf) do
    path =
      GraphManager.path_to_node(socket.assigns.graph_id, leaf)
      |> Enum.reverse()

    {:noreply, assign(socket, path: path)}
  end
end
