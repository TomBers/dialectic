defmodule DialecticWeb.LinearGraphLive do
  use DialecticWeb, :live_view

  alias Dialectic.Graph.GraphActions
  alias DialecticWeb.ColUtils

  on_mount {DialecticWeb.UserAuth, :mount_current_user}

  def mount(%{"graph_name" => graph_id_uri} = params, _session, socket) do
    graph_id = URI.decode(graph_id_uri)

    case Dialectic.DbActions.Graphs.get_graph_by_title(graph_id) do
      nil ->
        socket =
          socket
          |> put_flash(:error, "Graph not found: #{graph_id}")
          |> redirect(to: ~p"/")

        {:ok, socket}

      graph_db ->
        # Check Access
        token_param = Map.get(params, "token")

        has_access =
          Dialectic.DbActions.Sharing.can_access?(socket.assigns[:current_user], graph_db) or
            (is_binary(token_param) and is_binary(graph_db.share_token) and
               Plug.Crypto.secure_compare(token_param, graph_db.share_token))

        if has_access do
          try do
            # Ensure graph is loaded and available
            {_graph_struct, graph} = GraphManager.get_graph(graph_id)

            # Generate flat list for HTML minimap
            map_nodes =
              Dialectic.Linear.ThreadedConv.prepare_conversation(graph)
              |> Enum.reject(&(Map.get(&1, :compound, false) == true))
              |> Enum.map(fn node ->
                Map.put(node, :title, clean_title(node.content))
              end)

            # Determine which node to focus on.
            # If a node_id is provided in params, use it.
            # Otherwise, fall back to the "latest" leaf node to show a full conversation.
            target_node =
              if params["node_id"] do
                GraphActions.find_node(graph_id, params["node_id"])
              else
                GraphManager.find_leaf_nodes(graph_id)
                |> Enum.sort_by(
                  fn node ->
                    case Integer.parse(node.id) do
                      {int, _} -> int
                      _ -> 0
                    end
                  end,
                  :desc
                )
                |> List.first() || GraphManager.best_node(graph_id, nil)
              end

            # Build the linear path from Root -> Target
            linear_path =
              if target_node do
                GraphManager.path_to_node(graph_id, target_node)
                |> Enum.reverse()
                |> Enum.map(fn node -> Map.put(node, :title, clean_title(node.content)) end)
              else
                []
              end

            socket =
              assign(socket,
                linear_path: linear_path,
                map_nodes: map_nodes,
                graph_id: graph_id,
                show_minimap: true,
                selected_node_id: if(target_node, do: target_node.id, else: nil)
              )

            {:ok, socket}
          rescue
            _e ->
              socket =
                socket
                |> put_flash(:error, "Error loading graph: #{graph_id}")
                |> redirect(to: ~p"/")

              {:ok, socket}
          end
        else
          socket =
            socket
            |> put_flash(:error, "You do not have permission to view this graph.")
            |> redirect(to: ~p"/")

          {:ok, socket}
        end
    end
  end

  def handle_event("toggle_minimap", _, socket) do
    {:noreply, assign(socket, show_minimap: !socket.assigns.show_minimap)}
  end

  def handle_event("node_clicked", %{"id" => id}, socket) do
    node = GraphActions.find_node(socket.assigns.graph_id, id)

    if node do
      # Rebuild the path to the clicked node
      path =
        GraphManager.path_to_node(socket.assigns.graph_id, node)
        |> Enum.reverse()
        |> Enum.map(fn n -> Map.put(n, :title, clean_title(n.content)) end)

      {:noreply,
       socket
       |> assign(selected_node_id: node.id, linear_path: path)
       # Optionally scroll to the newly selected node in the linear view
       |> push_event("scroll_to_node", %{id: node.id})}
    else
      {:noreply, socket}
    end
  end

  def handle_event("prepare_for_print", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("update_exploration_progress", _params, socket) do
    {:noreply, socket}
  end

  defp message_border_class(class) do
    ColUtils.border_class(class)
  end

  defp clean_title(nil), do: ""

  defp clean_title(content) do
    content
    |> String.split("\n", parts: 2)
    |> List.first()
    # Remove markdown headers
    |> String.replace(~R/^\s*#{1,6}\s*/, "")
    # Remove bold
    |> String.replace(~r/\*\*/, "")
    |> String.trim()
  end
end
