defmodule DialecticWeb.GraphLive do
  use DialecticWeb, :live_view

  alias Dialectic.Graph.{Vertex, GraphActions, Siblings}
  alias DialecticWeb.{CombineComp, NodeComp}
  alias Dialectic.DbActions.DbWorker
  alias DialecticWeb.Utils.UserUtils
  alias Dialectic.Highlights

  alias Phoenix.PubSub

  require Logger

  on_mount {DialecticWeb.UserAuth, :mount_current_user}

  def mount(%{"graph_name" => graph_id_uri} = params, _session, socket) do
    graph_id = URI.decode(graph_id_uri)
    user = UserUtils.current_identity(socket.assigns)

    maybe_set_mode(graph_id, params)

    case fetch_graph(socket.assigns[:current_user], graph_id, params) do
      {:ok, {graph_struct, _}, graph_db} ->
        # Ensure a main group exists
        _ = ensure_main_group(graph_id)

        {node_id, initial_highlight_id} = resolve_target_node(graph_id, params)

        node =
          case GraphManager.best_node(graph_id, node_id) do
            nil -> default_node()
            v -> v
          end

        socket =
          socket
          |> assign_defaults()
          |> subscribe_to_topics(graph_id, user)
          |> assign_graph_data(graph_db, graph_struct, node, graph_id, user)
          |> handle_initial_highlight(initial_highlight_id)

        {:ok, socket}

      {:error, error_message} ->
        socket =
          socket
          |> put_flash(:error, error_message)
          |> redirect(to: ~p"/")

        {:ok, socket}
    end
  end

  defp default_node do
    %{id: "1", content: "", children: [], parents: []}
  end

  def handle_event("set_prompt_mode", %{"prompt_mode" => mode}, socket) do
    graph_id = socket.assigns.graph_id

    normalized =
      case String.downcase(to_string(mode)) do
        "creative" -> :creative
        _ -> :structured
      end

    if is_binary(graph_id) do
      _ = Dialectic.Responses.ModeServer.set_mode(graph_id, normalized)
    end

    mode_str = Atom.to_string(normalized)

    send_update(
      DialecticWeb.RightPanelComp,
      id: "right-panel-comp",
      prompt_mode: mode_str
    )

    {:noreply, assign(socket, prompt_mode: mode_str)}
  end

  def handle_event("toggle_graph_nav_panel", _params, socket) do
    {:noreply, assign(socket, show_graph_nav_panel: !socket.assigns.show_graph_nav_panel)}
  end

  def handle_event("node:join_group", %{"node" => nid, "parent" => gid}, socket) do
    _graph = GraphManager.set_parent(socket.assigns.graph_id, nid, gid)
    DbWorker.save_graph(socket.assigns.graph_id)

    {:noreply,
     socket
     |> assign(
       f_graph: GraphManager.format_graph_json(socket.assigns.graph_id),
       graph_operation: "join_group"
     )}
  end

  def handle_event("node:leave_group", %{"node" => nid}, socket) do
    # Server-side guard: do not allow leaving if it would leave the group empty
    case GraphManager.vertex_label(socket.assigns.graph_id, nid) do
      %{} = v ->
        parent_id = Map.get(v, :parent)

        if is_binary(parent_id) do
          children_count =
            GraphManager.vertices(socket.assigns.graph_id)
            |> Enum.count(fn vid ->
              case GraphManager.vertex_label(socket.assigns.graph_id, vid) do
                %{} = lbl -> Map.get(lbl, :parent) == parent_id
                _ -> false
              end
            end)

          if children_count <= 1 do
            # Block leaving the last child; no-op
            {:noreply, socket}
          else
            _graph = GraphManager.remove_parent(socket.assigns.graph_id, nid)
            DbWorker.save_graph(socket.assigns.graph_id)

            {:noreply,
             socket
             |> assign(
               f_graph: GraphManager.format_graph_json(socket.assigns.graph_id),
               graph_operation: "leave_group"
             )}
          end
        else
          {:noreply, socket}
        end

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("toggle_drawer", _, socket) do
    {:noreply, socket |> assign(drawer_open: !socket.assigns.drawer_open)}
  end

  def handle_event("toggle_right_panel", _, socket) do
    {:noreply, socket |> assign(right_panel_open: !socket.assigns.right_panel_open)}
  end

  def handle_event("toggle_bottom_menu", _, socket) do
    {:noreply, socket |> assign(bottom_menu_open: !socket.assigns.bottom_menu_open)}
  end

  # Handle form submission and change events
  def handle_event("search_nodes", params, socket) do
    search_term = params["search_term"] || params["value"] || ""

    if search_term == "" do
      {:noreply, socket |> assign(search_term: "", search_results: [])}
    else
      search_results =
        try do
          term = String.downcase(search_term)

          GraphManager.vertices(socket.assigns.graph_id)
          |> Enum.reduce([], fn vid, acc ->
            case GraphManager.vertex_label(socket.assigns.graph_id, vid) do
              %{} = vertex ->
                if valid_search_node(vertex) and
                     String.contains?(String.downcase(vertex.content), term) do
                  exact_match = if String.downcase(vertex.content) == term, do: 0, else: 1
                  [{exact_match, vertex.id, vertex} | acc]
                else
                  acc
                end

              _ ->
                acc
            end
          end)
          |> Enum.sort()
          |> Enum.map(fn {_, _, vertex} -> vertex end)
          |> Enum.take(10)
        rescue
          _ -> []
        end

      {:noreply, socket |> assign(search_term: search_term, search_results: search_results)}
    end
  end

  def handle_event("clear_search", _, socket) do
    {:noreply, socket |> assign(search_term: "", search_results: [])}
  end

  def handle_event("toggle_ask_question", _, socket) do
    {:noreply, assign(socket, ask_question: !socket.assigns.ask_question)}
  end

  def handle_event("toggle_lock_graph", _, socket) do
    graph_struct = GraphActions.toggle_graph_locked(graph_action_params(socket))
    can_edit = !graph_struct.is_locked
    {:noreply, socket |> assign(graph_struct: graph_struct, can_edit: can_edit)}
  end

  def handle_event("toggle_public_graph", _, socket) do
    graph_struct = GraphActions.toggle_graph_public(graph_action_params(socket))
    {:noreply, socket |> assign(graph_struct: graph_struct)}
  end

  def handle_event("note", %{"node" => node_id}, socket) do
    if socket.assigns.current_user == nil do
      {:noreply, assign(socket, show_login_modal: true)}
    else
      Dialectic.DbActions.Notes.add_note(
        socket.assigns.graph_id,
        node_id,
        socket.assigns.current_user
      )

      update_graph(
        socket,
        {nil,
         GraphActions.change_noted_by(
           graph_action_params(socket),
           node_id,
           &Vertex.add_noted_by/2
         )},
        "note"
      )
    end
  end

  def handle_event("toggle_node_menu", _, socket) do
    {:noreply,
     socket
     |> assign(:node_menu_visible, !socket.assigns.node_menu_visible)}
  end

  def handle_event("unnote", %{"node" => node_id}, socket) do
    if socket.assigns.current_user == nil do
      {:noreply, assign(socket, show_login_modal: true)}
    else
      Dialectic.DbActions.Notes.remove_note(
        socket.assigns.graph_id,
        node_id,
        socket.assigns.current_user
      )

      update_graph(
        socket,
        {nil,
         GraphActions.change_noted_by(
           graph_action_params(socket),
           node_id,
           &Vertex.remove_noted_by/2
         )},
        "unnote"
      )
    end
  end

  def handle_event("delete_node", %{"node" => node_id}, socket) do
    if !socket.assigns.can_edit do
      {:noreply, socket |> put_flash(:error, "This graph is locked")}
    else
      if socket.assigns.current_user == nil do
        {:noreply, assign(socket, show_login_modal: true)}
      else
        case GraphActions.find_node(socket.assigns.graph_id, node_id) do
          nil ->
            {:noreply, socket |> put_flash(:error, "Node not found")}

          node ->
            children = Map.get(node, :children, [])

            owns = UserUtils.owner?(node, socket.assigns)

            cond do
              not owns ->
                {:noreply, socket |> put_flash(:error, "You can only delete nodes you created")}

              Enum.any?(children, fn ch -> not Map.get(ch, :deleted, false) end) ->
                {:noreply,
                 socket |> put_flash(:error, "Cannot delete a node that has non-deleted children")}

              true ->
                next_node =
                  GraphActions.delete_node(graph_action_params(socket), node_id)

                DbWorker.save_graph(socket.assigns.graph_id)
                {_, _graph2} = GraphManager.get_graph(socket.assigns.graph_id)

                # Ensure we navigate to a valid, non-deleted node.
                # If no parent exists or it's invalid/deleted, pick the first non-deleted node in the graph.
                selected_node =
                  cond do
                    is_map(next_node) and not Map.get(next_node, :deleted, false) ->
                      # Resolve via manager to ensure relatives and current graph state
                      GraphActions.find_node(socket.assigns.graph_id, next_node.id)

                    true ->
                      fallback =
                        GraphManager.vertices(socket.assigns.graph_id)
                        |> Enum.find_value(fn vid ->
                          case GraphManager.vertex_label(socket.assigns.graph_id, vid) do
                            %{} = v ->
                              if not Map.get(v, :deleted, false), do: v, else: nil

                            _ ->
                              nil
                          end
                        end)

                      if fallback do
                        GraphActions.find_node(socket.assigns.graph_id, fallback.id)
                      else
                        default_node()
                      end
                  end

                {:noreply, updated_socket} =
                  update_graph(socket, {nil, selected_node}, "delete")

                {:noreply, updated_socket |> put_flash(:info, "Node deleted")}
            end
        end
      end
    end
  end

  def handle_event("branch_list", %{"items" => items}, socket) do
    if !socket.assigns.can_edit do
      {:noreply, socket |> put_flash(:error, "This graph is locked")}
    else
      last_result =
        Enum.reduce(items, nil, fn item, _acc ->
          GraphActions.answer_selection(
            graph_action_params(socket, socket.assigns.node),
            "Please explain: #{item}",
            "explain"
          )
        end)

      case last_result do
        node when is_map(node) ->
          update_graph(socket, {nil, node}, "explain")

        _ ->
          {:noreply, socket}
      end
    end
  end

  def handle_event("open_explore_modal", %{"items" => items}, socket) do
    if !socket.assigns.can_edit do
      {:noreply, socket |> put_flash(:error, "This graph is locked")}
    else
      {:noreply,
       socket
       |> assign(show_explore_modal: true, explore_items: items, explore_selected: [])}
    end
  end

  def handle_event("close_explore_modal", _, socket) do
    {:noreply, assign(socket, show_explore_modal: false, explore_items: [], explore_selected: [])}
  end

  def handle_event("submit_explore_modal", params, socket) do
    if !socket.assigns.can_edit do
      {:noreply, socket |> put_flash(:error, "This graph is locked")}
    else
      selected = normalize_explore_selected(params)

      if selected == [] do
        {:noreply, socket |> put_flash(:error, "Please select at least one point")}
      else
        last_result =
          Enum.reduce(selected, nil, fn item, _acc ->
            GraphActions.answer_selection(
              graph_action_params(socket, socket.assigns.node),
              "Please explain: #{item}",
              "explain"
            )
          end)

        case last_result do
          nil ->
            {:noreply, socket}

          node ->
            {:noreply, updated_socket} = update_graph(socket, {nil, node}, "explain")

            {:noreply,
             assign(updated_socket,
               show_explore_modal: false,
               explore_items: [],
               explore_selected: []
             )}
        end
      end
    end
  end

  def handle_event("node_branch", %{"id" => node_id}, socket) do
    if !socket.assigns.can_edit do
      {:noreply, socket |> put_flash(:error, "This graph is locked")}
    else
      node = GraphActions.find_node(socket.assigns.graph_id, node_id)
      # Ensure branching from the correct node
      update_graph(
        socket,
        {nil, GraphActions.branch(graph_action_params(socket, node))},
        "branch"
      )
    end
  end

  def handle_event("node_combine", %{"id" => node_id}, socket) do
    if !socket.assigns.can_edit do
      {:noreply, socket |> put_flash(:error, "This graph is locked")}
    else
      node = GraphActions.find_node(socket.assigns.graph_id, node_id)
      {:noreply, assign(socket, show_combine: true, node: node)}
    end
  end

  def handle_event("node_related_ideas", %{"id" => node_id}, socket) do
    if !socket.assigns.can_edit do
      {:noreply, socket |> put_flash(:error, "This graph is locked")}
    else
      node = GraphActions.find_node(socket.assigns.graph_id, node_id)

      update_graph(
        socket,
        {nil, GraphActions.related_ideas(graph_action_params(socket, node))},
        "ideas"
      )
    end
  end

  def handle_event("node_deepdive", %{"id" => node_id}, socket) do
    if !socket.assigns.can_edit do
      {:noreply, socket |> put_flash(:error, "This graph is locked")}
    else
      node = GraphActions.find_node(socket.assigns.graph_id, node_id)

      update_graph(
        socket,
        {nil, GraphActions.deepdive(graph_action_params(socket, node))},
        "deepdive"
      )
    end
  end

  def handle_event("node_regenerate", %{"id" => node_id}, socket) do
    if !socket.assigns.can_edit do
      {:noreply, socket |> put_flash(:error, "This graph is locked")}
    else
      case GraphActions.regenerate_node(graph_action_params(socket), node_id) do
        {:error, reason} ->
          {:noreply, socket |> put_flash(:error, reason)}

        {:ok, new_node} ->
          socket =
            assign(socket,
              streaming_nodes:
                socket.assigns.streaming_nodes
                |> MapSet.delete(node_id)
                |> MapSet.put(new_node.id)
            )

          update_graph(socket, {nil, new_node}, "regenerate")
      end
    end
  end

  def handle_event("combine_node_select", %{"selected_node" => node_id}, socket) do
    if !socket.assigns.can_edit do
      {:noreply, socket |> put_flash(:error, "This graph is locked")}
    else
      node =
        GraphActions.combine(
          graph_action_params(socket),
          node_id
        )

      update_graph(socket, {nil, node}, "combine")
    end
  end

  def handle_event("node_clicked", %{"id" => id}, socket) do
    # Determine if this was triggered from search results
    from_search = socket.assigns.search_term != "" and length(socket.assigns.search_results) > 0

    # Update the graph
    {:noreply, updated_socket} =
      update_graph(
        socket,
        {nil, GraphActions.find_node(socket.assigns.graph_id, id)},
        "node_clicked"
      )

    # Preserve and re-apply panel/menu state across node changes
    updated_socket = reapply_right_panel_state(socket, updated_socket)

    # Push event to center the node if coming from search
    if from_search do
      {:noreply, push_event(updated_socket, "center_node", %{id: id})}
    else
      {:noreply, updated_socket}
    end
  end

  def handle_event("highlight_clicked", %{"id" => highlight_id, "node-id" => node_id}, socket) do
    socket =
      if socket.assigns.node && socket.assigns.node.id == node_id do
        socket
      else
        case GraphManager.find_node_by_id(socket.assigns.graph_id, node_id) do
          nil ->
            socket

          node ->
            {_, socket} = update_graph(socket, {nil, node}, "node_clicked")

            socket
            |> push_event("center_node", %{id: node.id})
            |> push_event("expand_node", %{id: node.id})
        end
      end

    {:noreply, push_event(socket, "scroll_to_highlight", %{id: highlight_id})}
  end

  def handle_event("node_move", %{"direction" => direction}, socket) do
    if socket.assigns.node do
      {:noreply, updated_socket} =
        update_graph(
          socket,
          {nil, GraphActions.move(graph_action_params(socket), direction)},
          "node_clicked"
        )

      # Preserve and re-apply panel/menu state across node moves
      updated_socket = reapply_right_panel_state(socket, updated_socket)

      {:noreply, push_event(updated_socket, "center_node", %{id: updated_socket.assigns.node.id})}
    else
      {:noreply, socket}
    end
  end

  def handle_event("answer", %{"vertex" => %{"content" => ""}}, socket), do: {:noreply, socket}

  def handle_event("answer", %{"vertex" => %{"content" => answer}}, socket) do
    if socket.assigns.can_edit do
      update_graph(
        socket,
        {nil, GraphActions.comment(graph_action_params(socket), answer)},
        "comment"
      )
    else
      {:noreply, socket |> put_flash(:error, "This graph is locked")}
    end
  end

  def handle_event("reply-and-answer", %{"vertex" => %{"content" => answer}} = _params, socket) do
    cond do
      not socket.assigns.can_edit ->
        {:noreply, socket |> put_flash(:error, "This graph is locked")}

      true ->
        update_graph(
          socket,
          GraphActions.ask_and_answer(
            graph_action_params(socket, socket.assigns.node),
            answer
          ),
          "answer"
        )
    end
  end

  def handle_event("modal_closed", _, socket) do
    {:noreply, assign(socket, show_combine: false)}
  end

  # Start stream handlers grouped with other handle_event clauses
  def handle_event("open_share_modal", _params, socket) do
    socket =
      socket
      |> assign(show_share_modal: true)
      |> push_event("request_screenshot", %{})

    {:noreply, socket}
  end

  def handle_event("save_screenshot", %{"image" => image_data}, socket) do
    graph = socket.assigns.graph_struct
    # Update in memory only for modal display
    new_data = Map.put(graph.data || %{}, "preview_image", image_data)
    updated_graph = %{graph | data: new_data}

    {:noreply, assign(socket, graph_struct: updated_graph)}
  end

  def handle_event("close_share_modal", _params, socket) do
    {:noreply, assign(socket, show_share_modal: false)}
  end

  # Triggered by the client-side JS hook (text_selection_hook.js) when it receives a 401
  def handle_event("show_login_required", _, socket) do
    {:noreply, assign(socket, show_login_modal: true)}
  end

  def handle_event("close_login_modal", _, socket) do
    {:noreply, assign(socket, show_login_modal: false)}
  end

  def handle_event("open_start_stream_modal", _params, socket) do
    {:noreply, assign(socket, show_start_stream_modal: true)}
  end

  def handle_event("cancel_start_stream", _params, socket) do
    {:noreply, assign(socket, show_start_stream_modal: false)}
  end

  def handle_event("start_stream", %{"title" => title} = params, socket) do
    if !socket.assigns.can_edit do
      {:noreply, socket |> put_flash(:error, "This graph is locked")}
    else
      # 1) Optionally create a compound group to visually contain the stream
      group_id =
        if is_binary(title) and String.trim(title) != "" do
          title
        else
          nil
        end

      if group_id do
        GraphManager.create_group(socket.assigns.graph_id, group_id, [])
        DbWorker.save_graph(socket.assigns.graph_id)
      end

      # 2) Create a new root node under the group (if provided)
      content = title

      vertex = %Vertex{
        content: content,
        class: "origin",
        user: socket.assigns.user,
        parent: group_id
      }

      new_node = GraphManager.add_node(socket.assigns.graph_id, vertex)

      # 3) Load updated graph and node-with-relatives and update assigns/UI
      node2 = GraphManager.find_node_by_id(socket.assigns.graph_id, new_node.id)
      DbWorker.save_graph(socket.assigns.graph_id)

      final_node =
        if Map.get(params, "auto_answer") in ["on", "true", "1"] do
          GraphActions.answer(graph_action_params(socket, node2))
        else
          node2
        end

      update_graph(socket, {nil, final_node}, "start_stream")
    end
  end

  def handle_event("focus_stream", %{"id" => group_id}, socket) do
    {:noreply, push_event(socket, "focus_group", %{id: group_id})}
  end

  def handle_event("toggle_stream", %{"id" => group_id}, socket) do
    {:noreply, push_event(socket, "toggle_group", %{id: group_id})}
  end

  def handle_event("update_exploration_progress", params, socket) do
    {:noreply, assign(socket, :exploration_stats, params)}
  end

  def handle_info(:close_share_modal, socket) do
    {:noreply, assign(socket, show_share_modal: false)}
  end

  def handle_info({:created, highlight}, socket) do
    highlights = [highlight | socket.assigns.highlights]

    {:noreply,
     assign(socket, highlights: highlights)
     |> push_event("refresh_highlights", %{data: highlight})}
  end

  def handle_info({:updated, highlight}, socket) do
    highlights =
      Enum.map(socket.assigns.highlights, fn h ->
        if h.id == highlight.id, do: highlight, else: h
      end)

    {:noreply,
     assign(socket, highlights: highlights)
     |> push_event("refresh_highlights", %{data: highlight})}
  end

  def handle_info({:deleted, highlight}, socket) do
    highlights =
      Enum.reject(socket.assigns.highlights, fn h -> h.id == highlight.id end)

    {:noreply,
     assign(socket, highlights: highlights)
     |> push_event("refresh_highlights", %{data: highlight})}
  end

  def handle_info({DialecticWeb.Presence, {:join, presence}}, socket) do
    if is_connected_to_graph?(presence, socket.assigns.graph_id) do
      {:noreply, stream_insert(socket, :presences, presence)}
    else
      {:noreply, socket}
    end
  end

  def handle_info({DialecticWeb.Presence, {:leave, presence}}, socket) do
    if presence.metas == [] do
      {:noreply, stream_delete(socket, :presences, presence)}
    else
      {:noreply, stream_insert(socket, :presences, presence)}
    end
  end

  def handle_info({:other_user_change, sender_pid}, socket) do
    # Skip if it's our own change - we've already updated our view
    if self() != sender_pid do
      {_graph_struct, _graph} = GraphManager.get_graph(socket.assigns.graph_id)

      # Update f_graph so other users see structural changes (new nodes, etc.)
      {:noreply,
       assign(socket,
         f_graph: GraphManager.format_graph_json(socket.assigns.graph_id),
         work_streams: list_streams(socket.assigns.graph_id)
       )}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:stream_chunk, updated_vertex, :node_id, node_id}, socket) do
    # This is the streamed LLM response into a node
    # Re-broadcast to all users on the graph so they see real-time streaming
    PubSub.broadcast(
      Dialectic.PubSub,
      socket.assigns.graph_topic,
      {:stream_chunk_broadcast, updated_vertex, :node_id, node_id, self()}
    )

    {:noreply, update_streaming_node(socket, updated_vertex, node_id)}
  end

  def handle_info(
        {:stream_chunk_broadcast, updated_vertex, :node_id, node_id, sender_pid},
        socket
      ) do
    # Skip if this is our own broadcast (we already handled it above)
    if self() == sender_pid do
      {:noreply, socket}
    else
      # Another user is streaming - update our view if we're viewing this node
      {:noreply, update_streaming_node(socket, updated_vertex, node_id)}
    end
  end

  def handle_info({:llm_request_complete, node_id}, socket) do
    Logger.debug(fn ->
      "[GraphLive] llm_request_complete node_id=#{inspect(node_id)} current=#{inspect(socket.assigns.node && Map.get(socket.assigns.node, :id))}"
    end)

    socket =
      socket
      |> assign(streaming_nodes: MapSet.delete(socket.assigns.streaming_nodes, node_id))
      |> assign(work_streams: list_streams(socket.assigns.graph_id))

    # Don't broadcast or call update_graph - the streaming already updated the node content
    # and we don't want to cause a flash/rerender for the user watching the stream
    # Other users will see the node when it was created, not when it completes
    {:noreply, socket}
  end

  def handle_info({:stream_error, error, :node_id, node_id}, socket) do
    Logger.debug(fn ->
      "[GraphLive] stream_error node_id=#{inspect(node_id)} current=#{inspect(socket.assigns.node && Map.get(socket.assigns.node, :id))} error=#{inspect(error)}"
    end)

    # This is the streamed LLM response into a node
    # TODO - broadcast to all users??? - only want to update the node that is being worked on, just rerender the others
    updated_vertex = GraphManager.update_vertex(socket.assigns.graph_id, node_id, error)

    if socket.assigns.node && node_id == Map.get(socket.assigns.node, :id) do
      label = extract_title(Map.get(updated_vertex, :content, ""))

      socket =
        socket
        |> assign(node: updated_vertex)
        |> push_event("update_node_label", %{id: node_id, label: label})

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  defp is_connected_to_graph?(%{metas: metas}, graph_id) do
    Enum.any?(metas, fn %{graph_id: gid} -> gid == graph_id end)
  end

  def format_graph(graph) do
    if is_nil(graph) do
      # Return empty JSON array if graph is nil
      "[]"
    else
      try do
        graph |> Vertex.to_cytoscape_format() |> Jason.encode!()
      rescue
        # Return empty JSON array on error
        _ -> "[]"
      end
    end
  end

  # Sanitizes a string to be used as a graph title.
  #
  # Removes any characters that would cause issues when used in URLs or as graph identifiers.
  def sanitize_graph_title(title) do
    title
    |> String.trim()
    # Only allow letters, numbers, spaces, ASCII and Unicode dashes and apostrophes
    |> String.replace(~r/[^a-zA-Z0-9\s"'’,“”\-–—]/u, "")
    # Replace multiple spaces with single space
    |> String.replace(~r/\s+/, " ")
  end

  # Search for nodes in the graph based on a search term

  defp valid_search_node(vertex_data) do
    # First ensure we have a vertex_data that's a map
    # Then check if it has all required fields
    # Make sure content is a string
    # Ensure ID is non-nil and valid
    # And the node isn't marked as deleted
    vertex_data != nil and is_map(vertex_data) and
      Map.has_key?(vertex_data, :content) and
      Map.has_key?(vertex_data, :id) and
      is_binary(Map.get(vertex_data, :content, "")) and
      Map.get(vertex_data, :id) != nil and
      not Map.get(vertex_data, :deleted, false)
  end

  defp normalize_explore_selected(params) do
    cond do
      is_list(params) ->
        Enum.filter(params, &is_binary/1)

      is_map(params) and is_list(Map.get(params, "selected")) ->
        Enum.filter(Map.get(params, "selected"), &is_binary/1)

      is_map(params) and is_list(Map.get(params, "items")) ->
        Enum.filter(Map.get(params, "items"), &is_binary/1)

      is_map(params) and is_map(Map.get(params, "items")) ->
        params["items"]
        |> Enum.flat_map(fn {k, v} ->
          cond do
            v in ["on", "true", "1"] -> [k]
            is_binary(v) -> [v]
            true -> []
          end
        end)

      true ->
        []
    end
  end

  defp graph_action_params(socket, node \\ nil) do
    # Make sure we have a valid node to work with
    node_to_use =
      cond do
        node != nil -> node
        is_map(socket.assigns.node) -> socket.assigns.node
        true -> default_node()
      end

    # Make sure the graph exists before making a call
    graph_id = socket.assigns.graph_id

    unless GraphManager.exists?(graph_id) do
      # Check if the graph exists in the database
      case Dialectic.DbActions.Graphs.get_graph_by_title(graph_id) do
        nil ->
          # If graph doesn't exist in DB, we shouldn't be here
          # This is a safety check since the user should have been redirected already
          # Just log a warning, don't create a new graph
          require Logger
          Logger.warning("Attempted to access non-existent graph: #{graph_id}")

        _graph ->
          # Graph exists in DB but not in memory, initialize it
          DynamicSupervisor.start_child(GraphSupervisor, {GraphManager, graph_id})
      end
    end

    {graph_id, node_to_use, socket.assigns.user, socket.assigns.live_view_topic}
  end

  defp compute_nav_flags(graph, node) do
    can_up = node != nil and is_list(node.parents) and List.first(node.parents) != nil
    can_down = node != nil and is_list(node.children) and List.first(node.children) != nil

    siblings =
      try do
        case graph do
          id when is_binary(id) -> Siblings.sort_siblings(node, id)
          _ -> Siblings.sort_siblings(node, graph)
        end
      rescue
        _ -> []
      end

    {can_left, can_right} =
      case Enum.find_index(siblings, fn n -> n.id == node.id end) do
        nil -> {false, false}
        0 -> {false, length(siblings) > 1}
        idx when idx == length(siblings) - 1 -> {length(siblings) > 1, false}
        _ -> {true, true}
      end

    {can_up, can_down, can_left, can_right}
  end

  defp list_streams(graph_id) do
    try do
      GraphManager.vertices(graph_id)
      |> Enum.reduce([], fn vid, acc ->
        case GraphManager.vertex_label(graph_id, vid) do
          %{} = v ->
            if Map.get(v, :compound) == true do
              [%{id: v.id} | acc]
            else
              acc
            end

          _ ->
            acc
        end
      end)
      |> Enum.reverse()
    rescue
      _ -> []
    end
  end

  defp ensure_main_group(graph_id) do
    GraphManager.ensure_main_group(graph_id)
  end

  def update_graph(socket, {_graph, node}, operation) do
    # Changeset needs to be a new node
    new_node = GraphActions.create_new_node(socket.assigns.user)
    changeset = Vertex.changeset(new_node)

    show_combine =
      if operation == "combine" do
        !socket.assigns.show_combine
      else
        socket.assigns.show_combine
      end

    # Clear search when a node is clicked from search results
    socket =
      if operation == "node_clicked" and socket.assigns.search_term != "" do
        assign(socket, search_term: "", search_results: [])
      else
        socket
      end

    {nav_up, nav_down, nav_left, nav_right} = compute_nav_flags(socket.assigns.graph_id, node)

    new_socket =
      assign(socket,
        f_graph: GraphManager.format_graph_json(socket.assigns.graph_id),
        form:
          if operation in ["llm_request_complete"] do
            socket.assigns.form
          else
            to_form(changeset, id: new_node.id)
          end,
        node: node,
        show_combine: show_combine,
        graph_operation: operation,
        open_read_modal: false,
        nav_can_up: nav_up,
        nav_can_down: nav_down,
        nav_can_left: nav_left,
        nav_can_right: nav_right,
        work_streams: list_streams(socket.assigns.graph_id),
        prompt_mode:
          Atom.to_string(Dialectic.Responses.ModeServer.get_mode(socket.assigns.graph_id))
      )
      |> assign(:ask_question, socket.assigns.ask_question)
      |> then(fn s ->
        # Close the start stream modal if applicable
        if operation == "start_stream" do
          assign(s, show_start_stream_modal: false)
        else
          s
        end
      end)
      |> then(fn s ->
        # Ensure newly created nodes are selected immediately
        if operation in [
             "start_stream",
             "comment",
             "answer",
             "branch",
             "combine",
             "ideas",
             "explain",
             "deepdive"
           ] &&
             node && Map.get(node, :id) do
          push_event(s, "center_node", %{id: node.id})
        else
          s
        end
      end)

    # Broadcast structural changes to other users (new nodes created, etc.)
    # Skip for operations that don't change graph structure
    if operation in [
         "start_stream",
         "comment",
         "answer",
         "branch",
         "combine",
         "ideas",
         "explain",
         "deepdive"
       ] do
      PubSub.broadcast(
        Dialectic.PubSub,
        socket.assigns.graph_topic,
        {:other_user_change, self()}
      )
    end

    {:noreply, new_socket}
  end

  # Helper to preserve and re-apply right panel state across node changes/moves
  defp reapply_right_panel_state(socket, updated_socket) do
    updated_socket =
      updated_socket
      |> assign(:group_states, socket.assigns[:group_states] || %{})

    send_update(
      DialecticWeb.RightPanelComp,
      id: "right-panel-comp",
      group_states: updated_socket.assigns[:group_states]
    )

    updated_socket
  end

  defp extract_title(content) do
    content
    |> to_string()
    |> String.replace(~r/\r\n|\r/, "\n")
    |> String.split("\n")
    |> List.first()
    |> Kernel.||("")
    |> String.replace(~r/^\s*\#{1,6}\s*/, "")
    |> String.replace(~r/^\s*title\s*:?\s*/i, "")
    |> String.replace("**", "")
    |> String.trim()
  end

  defp update_streaming_node(socket, updated_vertex, node_id) do
    if socket.assigns.node && node_id == Map.get(socket.assigns.node, :id) do
      label = extract_title(Map.get(updated_vertex, :content, ""))

      # Merge content update while preserving relatives (parents/children)
      node = %{socket.assigns.node | content: updated_vertex.content}

      socket
      |> assign(node: node)
      |> push_event("update_node_label", %{id: node_id, label: label})
    else
      socket
    end
  end

  defp maybe_set_mode(graph_id, params) do
    mode_param = Map.get(params, "mode")

    if is_binary(mode_param) do
      normalized =
        case String.downcase(mode_param) do
          "creative" -> :creative
          "structured" -> :structured
          _ -> nil
        end

      if normalized do
        _ = Dialectic.Responses.ModeServer.set_mode(graph_id, normalized)
      end
    end
  end

  defp fetch_graph(user, graph_id, params) do
    case Dialectic.DbActions.Graphs.get_graph_by_title(graph_id) do
      nil ->
        {:error, "Graph not found: #{graph_id}"}

      graph_db ->
        token_param = Map.get(params, "token")

        has_access =
          Dialectic.DbActions.Sharing.can_access?(user, graph_db) or
            (is_binary(token_param) and is_binary(graph_db.share_token) and
               Plug.Crypto.secure_compare(token_param, graph_db.share_token))

        if has_access do
          try do
            {:ok, GraphManager.get_graph(graph_id), graph_db}
          rescue
            _e ->
              require Logger
              Logger.error("Failed to load graph: #{graph_id}")
              {:error, "Error loading graph: #{graph_id}"}
          end
        else
          {:error, "You do not have permission to view this graph."}
        end
    end
  end

  defp resolve_target_node(graph_id, params) do
    highlight_param = Map.get(params, "highlight")

    if highlight_param do
      case Highlights.get_highlight(highlight_param) do
        %{mudg_id: ^graph_id, node_id: h_node_id, id: h_id} ->
          {h_node_id, h_id}

        _ ->
          {Map.get(params, "node", "1"), nil}
      end
    else
      {Map.get(params, "node", "1"), nil}
    end
  end

  defp assign_defaults(socket) do
    user = UserUtils.current_identity(socket.assigns)

    assign(socket,
      user: user,
      current_user: socket.assigns[:current_user],
      streaming_nodes: MapSet.new(),
      show_combine: false,
      drawer_open: true,
      right_panel_open: false,
      bottom_menu_open: true,
      graph_operation: "",
      ask_question: true,
      group_states: %{},
      search_term: "",
      search_results: [],
      nav_can_up: false,
      nav_can_down: false,
      nav_can_left: false,
      nav_can_right: false,
      open_read_modal: false,
      show_explore_modal: false,
      explore_items: [],
      explore_selected: [],
      show_start_stream_modal: false,
      show_share_modal: false,
      work_streams: [],
      exploration_stats: nil,
      show_login_modal: false,
      show_graph_nav_panel: true
    )
  end

  defp subscribe_to_topics(socket, graph_id, user) do
    if connected?(socket) do
      live_view_topic = "graph_update:#{socket.id}"
      graph_topic = "graph_update:#{graph_id}"

      Phoenix.PubSub.subscribe(Dialectic.PubSub, live_view_topic)
      Phoenix.PubSub.subscribe(Dialectic.PubSub, graph_topic)
      Highlights.subscribe(graph_id)
      DialecticWeb.Presence.track_user(user, %{id: user, graph_id: graph_id})
      DialecticWeb.Presence.subscribe()

      presences = DialecticWeb.Presence.list_online_users(graph_id)

      stream(socket, :presences, presences)
    else
      stream(socket, :presences, [])
    end
  end

  defp assign_graph_data(socket, _graph_db, graph_struct, node, graph_id, user) do
    changeset = GraphActions.create_new_node(user) |> Vertex.changeset()
    can_edit = !graph_struct.is_locked
    {nav_up, nav_down, nav_left, nav_right} = compute_nav_flags(graph_id, node)

    assign(socket,
      page_title: graph_struct.title,
      og_image: DialecticWeb.Endpoint.url() <> ~p"/images/graph_live.webp",
      page_description:
        "Explore the interactive map for \"#{graph_struct.title}\". Visualize arguments, discover connections, and collaborate on MuDG.",
      live_view_topic: "graph_update:#{socket.id}",
      graph_topic: "graph_update:#{graph_id}",
      graph_struct: graph_struct,
      graph_id: graph_id,
      f_graph: GraphManager.format_graph_json(graph_id),
      node: node,
      form: to_form(changeset),
      can_edit: can_edit,
      node_menu_visible: true,
      nav_can_up: nav_up,
      nav_can_down: nav_down,
      nav_can_left: nav_left,
      nav_can_right: nav_right,
      work_streams: list_streams(graph_id),
      prompt_mode: Atom.to_string(Dialectic.Responses.ModeServer.get_mode(graph_id)),
      highlights: Highlights.list_highlights(mudg_id: graph_id)
    )
  end

  defp handle_initial_highlight(socket, highlight_id) do
    if connected?(socket) && highlight_id do
      push_event(socket, "scroll_to_highlight", %{id: highlight_id})
    else
      socket
    end
  end
end
