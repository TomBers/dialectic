defmodule DialecticWeb.StoryLive do
  use DialecticWeb, :live_view

  def mount(%{"graph_name" => graph_id_uri, "node_id" => node_id_uri}, _session, socket) do
    graph_id = URI.decode(graph_id_uri)
    node_id = URI.decode(node_id_uri)

    # Ensure graph is started
    GraphManager.get_graph(graph_id)

    node = GraphManager.find_node_by_id(graph_id, node_id)

    path =
      GraphManager.path_to_node(graph_id, node)
      |> Enum.reverse()

    {:ok, assign(socket, graph_id: graph_id, node_id: node_id, path: path)}
  end
end
