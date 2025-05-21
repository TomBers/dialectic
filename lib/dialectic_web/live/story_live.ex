defmodule DialecticWeb.StoryLive do
  use DialecticWeb, :live_view

  def mount(%{"graph_name" => graph_id_uri}, _session, socket) do
    graph_id = URI.decode(graph_id_uri)

    leaf_nodes = GraphManager.find_leaf_nodes(graph_id)

    ln = List.first(leaf_nodes)

    path =
      GraphManager.path_to_node(graph_id, ln)
      |> Enum.reverse()

    {:ok, assign(socket, graph_id: graph_id, path: path, leaf_nodes: leaf_nodes, p_index: 0)}
  end

  def handle_event("next", _, socket) do
    p_indx =
      if socket.assigns.p_index < length(socket.assigns.leaf_nodes) - 1 do
        socket.assigns.p_index + 1
      else
        0
      end

    IO.inspect(p_indx, label: "P Index")

    return_path(
      socket,
      p_indx
    )
  end

  def handle_event("previous", _, socket) do
    p_indx =
      if socket.assigns.p_index > 1 do
        socket.assigns.p_index - 1
      else
        length(socket.assigns.leaf_nodes) - 1
      end

    IO.inspect(p_indx, label: "P Index")

    return_path(
      socket,
      p_indx
    )
  end

  defp return_path(socket, p_index) do
    leaf = Enum.at(socket.assigns.leaf_nodes, p_index)

    path =
      GraphManager.path_to_node(socket.assigns.graph_id, leaf)
      |> Enum.reverse()

    {:noreply, assign(socket, path: path, p_index: p_index)}
  end
end
