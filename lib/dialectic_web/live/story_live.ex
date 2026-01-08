defmodule DialecticWeb.StoryLive do
  use DialecticWeb, :live_view

  def mount(%{"graph_name" => graph_id_uri, "node_id" => node_id_uri}, _session, socket) do
    graph_id = URI.decode(graph_id_uri)
    node_id = URI.decode(node_id_uri)

    # Try slug first, then title for backward compatibility
    case Dialectic.DbActions.Graphs.get_graph_by_slug_or_title(graph_id) do
      nil ->
        socket =
          socket
          |> put_flash(:error, "Graph not found: #{graph_id}")
          |> redirect(to: ~p"/")

        {:ok, socket}

      graph_db ->
        # Ensure graph is started (use title for internal GraphManager)
        GraphManager.get_graph(graph_db.title)

        node = GraphManager.find_node_by_id(graph_db.title, node_id)

        path =
          GraphManager.path_to_node(graph_db.title, node)
          |> Enum.reverse()

        {:ok,
         assign(socket,
           graph_id: graph_db.title,
           graph_struct: graph_db,
           node_id: node_id,
           path: path
         )}
    end
  end
end
