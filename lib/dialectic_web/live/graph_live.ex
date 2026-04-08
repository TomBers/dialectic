defmodule DialecticWeb.GraphLive do
  use DialecticWeb, :live_view
  use DialecticWeb.GraphStreaming, preload_highlight_links: true

  alias Dialectic.Graph.{Vertex, GraphActions, Siblings}
  alias Dialectic.Accounts.User
  alias DialecticWeb.NodeComp
  alias DialecticWeb.GraphHelpers

  alias DialecticWeb.Utils.UserUtils
  alias DialecticWeb.Utils.NodeTitleHelper
  alias Dialectic.Highlights
  alias Dialectic.Repo

  alias Phoenix.PubSub

  import Ecto.Query

  require Logger

  on_mount {DialecticWeb.UserAuth, :mount_current_user}

  # ── handle_params: auto-start presentation from URL query params ──
  # Called after mount on initial page load and on every live_patch.
  # Detects ?present=true&slides=1,2,3&title=... and boots directly into
  # presenting mode so shared links open the presentation automatically.
  def handle_params(%{"present" => "true", "slides" => slides_str} = params, _uri, socket) do
    slide_ids =
      slides_str
      |> String.split(",", trim: true)
      |> Enum.map(&String.trim/1)
      |> Enum.filter(&(&1 != ""))
      |> Enum.map(&String.to_integer/1)
      |> Enum.map(&to_string/1)

    # Filter out IDs for nodes that no longer exist in the graph so that
    # stale shared links degrade gracefully (correct slide count, no gaps
    # in badge numbering, and an empty-slides fallback when all are gone).
    graph_id = socket.assigns.graph_id

    valid_slide_ids =
      Enum.filter(slide_ids, fn id ->
        GraphActions.find_node(graph_id, id) != nil
      end)

    title =
      case Map.get(params, "title") do
        nil -> socket.assigns.graph_struct.title
        "" -> socket.assigns.graph_struct.title
        t -> t
      end

    if length(valid_slide_ids) > 0 and connected?(socket) do
      socket =
        socket
        |> assign(
          presentation_mode: :presenting,
          presentation_slide_ids: valid_slide_ids,
          presentation_title: title
        )
        |> push_event("presentation_clear_slides", %{})
        |> push_event("presentation_filter_graph", %{ids: valid_slide_ids})
        |> push_event("toggle_site_header", %{visible: false})

      {:noreply, socket}
    else
      # No valid slides remain (all deleted) or static render — stay in
      # normal mode so the user sees the full graph instead of a blank screen.
      {:noreply,
       socket
       |> assign(
         presentation_slide_ids: valid_slide_ids,
         presentation_title: title
       )}
    end
  end

  def handle_params(_params, _uri, socket), do: {:noreply, socket}

  def mount(%{"graph_name" => graph_id_uri} = params, _session, socket) do
    graph_id = URI.decode(graph_id_uri)
    user = UserUtils.current_identity(socket.assigns)

    case fetch_graph(socket.assigns[:current_user], graph_id, params) do
      {:ok, {graph_struct, _}, graph_db} ->
        # Use the actual title for all internal operations
        graph_title = graph_db.title

        _ =
          Dialectic.Responses.ModeServer.set_mode(
            graph_title,
            graph_db.prompt_mode || "university"
          )

        # Ensure a main group exists
        _ = ensure_main_group(graph_title)

        {node_id, initial_highlight_id} = resolve_target_node(graph_title, params)

        node =
          case GraphManager.best_node(graph_title, node_id) do
            nil -> default_node()
            v -> v
          end

        socket =
          socket
          |> assign_defaults()
          |> subscribe_to_topics(graph_title, user)
          |> assign_graph_data(graph_db, graph_struct, node, graph_title, user)
          |> assign(token: params["token"])
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
    GraphHelpers.default_node()
  end

  def handle_event("set_prompt_mode", %{"prompt_mode" => mode}, socket) do
    graph_id = socket.assigns.graph_id

    normalized =
      case String.downcase(to_string(mode)) do
        "expert" -> :expert
        "high_school" -> :high_school
        "simple" -> :simple
        _ -> :university
      end

    mode_str = Atom.to_string(normalized)

    if is_binary(graph_id) do
      _ = Dialectic.Responses.ModeServer.set_mode(graph_id, normalized)

      case Dialectic.DbActions.Graphs.get_graph_by_title(graph_id) do
        nil ->
          :noop

        graph ->
          graph
          |> Dialectic.Accounts.Graph.changeset(%{prompt_mode: mode_str})
          |> Dialectic.Repo.update()
      end
    end

    send_update(
      DialecticWeb.RightPanelComp,
      id: "right-panel-comp",
      prompt_mode: mode_str
    )

    {:noreply, assign(socket, prompt_mode: mode_str)}
  end

  def handle_event("node:join_group", %{"node" => nid, "parent" => gid}, socket) do
    _graph = GraphManager.set_parent(socket.assigns.graph_id, nid, gid)
    GraphManager.save_graph(socket.assigns.graph_id)

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
            GraphManager.save_graph(socket.assigns.graph_id)

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

  # Handle form submission and change events
  def handle_event("search_nodes", params, socket) do
    search_term = params["search_term"] || params["value"] || ""

    if search_term == "" do
      {:noreply,
       socket
       |> assign(search_term: "", search_results: [])
       |> push_event("clear_search_highlights", %{})}
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

      matching_ids = Enum.map(search_results, & &1.id)

      {:noreply,
       socket
       |> assign(search_term: search_term, search_results: search_results)
       |> push_event("highlight_search_results", %{ids: matching_ids})}
    end
  end

  def handle_event("clear_search", _, socket) do
    {:noreply,
     socket
     |> assign(search_term: "", search_results: [])
     |> push_event("clear_search_highlights", %{})}
  end

  def handle_event("open_search_overlay_click", _params, socket) do
    {:noreply, assign(socket, show_search_overlay: true)}
  end

  def handle_event("open_search_overlay", params, socket) do
    meta = params["metaKey"] in [true, "true"]
    cmd = params["cmdKey"] in [true, "true"]
    editable = params["isEditable"] in [true, "true"]

    if (meta || cmd) && !editable do
      {:noreply, assign(socket, show_search_overlay: true)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("close_search_overlay", _, socket) do
    {:noreply,
     socket
     |> assign(show_search_overlay: false, search_term: "", search_results: [])
     |> push_event("clear_search_highlights", %{})}
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
    case GraphHelpers.handle_note(socket, node_id, :note) do
      {:noreply, socket} -> {:noreply, socket}
      {:ok, graph_result, operation} -> update_graph(socket, graph_result, operation)
    end
  end

  def handle_event("toggle_node_menu", _, socket) do
    {:noreply,
     socket
     |> assign(:node_menu_visible, !socket.assigns.node_menu_visible)}
  end

  def handle_event("unnote", %{"node" => node_id}, socket) do
    case GraphHelpers.handle_note(socket, node_id, :unnote) do
      {:noreply, socket} -> {:noreply, socket}
      {:ok, graph_result, operation} -> update_graph(socket, graph_result, operation)
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
                # Remove any highlight links that point to this node
                alias Dialectic.Highlights.HighlightLink

                Repo.delete_all(
                  from l in HighlightLink,
                    where: l.node_id == ^node_id
                )

                next_node =
                  GraphActions.delete_node(graph_action_params(socket), node_id)

                GraphManager.save_graph(socket.assigns.graph_id)
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
    case GraphHelpers.handle_branch(socket, node_id) do
      {:ok, graph_result, operation} -> update_graph(socket, graph_result, operation)
      {:error, :locked} -> {:noreply, socket |> put_flash(:error, "This graph is locked")}
    end
  end

  def handle_event("node_combine", _params, socket) do
    if !socket.assigns.can_edit do
      {:noreply, socket |> put_flash(:error, "This graph is locked")}
    else
      # Toggle: if already in setup, close the panel; otherwise open it
      if socket.assigns.combine_mode == :setup do
        socket =
          socket
          |> assign(combine_mode: :off, combine_selected_nodes: [])
          |> push_event("combine_clear_highlights", %{})

        {:noreply, socket}
      else
        socket =
          socket
          |> assign(combine_mode: :setup, combine_selected_nodes: [])

        {:noreply, socket}
      end
    end
  end

  def handle_event("node_related_ideas", %{"id" => node_id}, socket) do
    case GraphHelpers.handle_related_ideas(socket, node_id) do
      {:ok, graph_result, operation} -> update_graph(socket, graph_result, operation)
      {:error, :locked} -> {:noreply, socket |> put_flash(:error, "This graph is locked")}
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

  def handle_event("navigate_to_node", %{"node_id" => node_id} = _params, socket) do
    # Navigate to a node (e.g., from clicking a highlight link)
    node = GraphActions.find_node(socket.assigns.graph_id, node_id)

    if node do
      {:noreply, updated_socket} =
        update_graph(
          socket,
          {nil, node},
          "node_clicked"
        )

      # Center and expand the node
      updated_socket =
        updated_socket
        |> push_event("center_node", %{id: node_id})
        |> push_event("expand_node", %{id: node_id})

      {:noreply, updated_socket}
    else
      {:noreply, socket |> put_flash(:error, "Node not found")}
    end
  end

  def handle_event("node_clicked", %{"id" => id} = params, socket) do
    # When in combine setup mode, clicking a node toggles it in the selection
    cond do
      socket.assigns.combine_mode == :setup ->
        selected = socket.assigns.combine_selected_nodes
        node = GraphActions.find_node(socket.assigns.graph_id, id)
        from_search = params["from-search"] == "true"

        if node == nil do
          {:noreply, socket}
        else
          updated_selected =
            if Enum.any?(selected, fn n -> n.id == id end) do
              Enum.reject(selected, fn n -> n.id == id end)
            else
              # Only allow 2 nodes to be selected
              if length(selected) < 2 do
                selected ++ [node]
              else
                selected
              end
            end

          {:noreply, updated_socket} =
            update_graph(socket, {nil, node}, "node_clicked")

          updated_socket = reapply_right_panel_state(socket, updated_socket)

          updated_socket =
            updated_socket
            |> assign(combine_selected_nodes: updated_selected)
            |> push_event("combine_highlight_nodes", %{ids: Enum.map(updated_selected, & &1.id)})
            |> push_event("center_node", %{id: id})
            |> then(fn s ->
              if from_search do
                s
                |> assign(show_search_overlay: false, search_term: "", search_results: [])
                |> push_event("clear_search_highlights", %{})
              else
                s
              end
            end)

          {:noreply, updated_socket}
        end

      socket.assigns.presentation_mode == :setup ->
        ids = socket.assigns.presentation_slide_ids
        from_search = params["from-search"] == "true"

        updated_ids =
          if id in ids do
            List.delete(ids, id)
          else
            ids ++ [id]
          end

        # Still navigate to the node so the user can see its content
        node = GraphActions.find_node(socket.assigns.graph_id, id)

        if node == nil do
          socket =
            socket
            |> assign(presentation_slide_ids: updated_ids)
            |> push_presentation_highlights()
            |> push_presentation_persistence()
            |> then(fn s ->
              if from_search do
                s
                |> assign(show_search_overlay: false, search_term: "", search_results: [])
                |> push_event("clear_search_highlights", %{})
              else
                s
              end
            end)

          {:noreply, socket}
        else
          {:noreply, updated_socket} =
            update_graph(socket, {nil, node}, "node_clicked")

          updated_socket = reapply_right_panel_state(socket, updated_socket)

          updated_socket =
            updated_socket
            |> assign(presentation_slide_ids: updated_ids)
            |> push_presentation_highlights()
            |> push_presentation_persistence()
            |> push_event("center_node", %{id: id})
            |> then(fn s ->
              if from_search do
                s
                |> assign(show_search_overlay: false, search_term: "", search_results: [])
                |> push_event("clear_search_highlights", %{})
              else
                s
              end
            end)

          {:noreply, updated_socket}
        end

      true ->
        # Normal mode — original behaviour
        # Determine if this was triggered from search results via explicit param
        from_search = params["from-search"] == "true"

        # Update the graph
        node = GraphActions.find_node(socket.assigns.graph_id, id)

        if node == nil do
          {:noreply, socket}
        else
          {:noreply, updated_socket} =
            update_graph(socket, {nil, node}, "node_clicked")

          # Preserve and re-apply panel/menu state across node changes
          updated_socket = reapply_right_panel_state(socket, updated_socket)

          # Close the quick search overlay and clear highlights when navigating from search
          updated_socket =
            if from_search do
              updated_socket
              |> assign(show_search_overlay: false, search_term: "", search_results: [])
              |> push_event("clear_search_highlights", %{})
              |> push_event("center_node", %{id: id})
            else
              # Always center the node on the graph (e.g. when clicked from the ask form indicator)
              push_event(updated_socket, "center_node", %{id: id})
            end

          {:noreply, updated_socket}
        end
    end
  end

  def handle_event("highlight_clicked", %{"id" => highlight_id, "node-id" => node_id}, socket) do
    socket =
      if socket.assigns.node && socket.assigns.node.id == node_id do
        socket
        |> push_event("center_node", %{id: node_id})
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

  # Ignore arrow-key navigation when the user is typing in a text field
  def handle_event("node_move", %{"isEditable" => true}, socket), do: {:noreply, socket}

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
    case GraphHelpers.handle_answer(socket, answer) do
      {:ok, graph_result, operation} ->
        update_graph(socket, graph_result, operation)

      {:error, :locked} ->
        {:noreply, socket |> put_flash(:error, "This graph is locked")}
    end
  end

  # Ignore empty submissions for both Ask (AI) and Post (comment-only) paths
  def handle_event("reply-and-answer", %{"vertex" => %{"content" => ""}}, socket),
    do: {:noreply, socket}

  def handle_event(
        "reply-and-answer",
        %{"vertex" => %{"content" => answer}, "submit_action" => "post"},
        socket
      ) do
    case GraphHelpers.handle_answer(socket, answer) do
      {:ok, graph_result, operation} ->
        update_graph(socket, graph_result, operation)

      {:error, :locked} ->
        {:noreply, socket |> put_flash(:error, "This graph is locked")}
    end
  end

  def handle_event(
        "reply-and-answer",
        %{"vertex" => %{"content" => answer}, "prefix" => prefix} = params,
        socket
      ) do
    minimal_context = prefix == "explain"
    highlight_context = Map.get(params, "highlight_context")

    case GraphHelpers.handle_reply_and_answer(socket, answer,
           minimal_context: minimal_context,
           highlight_context: highlight_context
         ) do
      {:ok, graph_result, operation} ->
        update_graph(socket, graph_result, operation)

      {:error, :locked} ->
        {:noreply, socket |> put_flash(:error, "This graph is locked")}
    end
  end

  def handle_event("reply-and-answer", %{"vertex" => %{"content" => answer}} = params, socket) do
    highlight_context = Map.get(params, "highlight_context")

    case GraphHelpers.handle_reply_and_answer(socket, answer,
           highlight_context: highlight_context
         ) do
      {:ok, graph_result, operation} ->
        update_graph(socket, graph_result, operation)

      {:error, :locked} ->
        {:noreply, socket |> put_flash(:error, "This graph is locked")}
    end
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
        GraphManager.save_graph(socket.assigns.graph_id)
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
      GraphManager.save_graph(socket.assigns.graph_id)

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

  def handle_event("delete_stream", %{"id" => group_id}, socket) do
    if !socket.assigns.can_edit do
      {:noreply, socket |> put_flash(:error, "This graph is locked")}
    else
      # Validate group_id is not blank or "Main"
      cond do
        String.trim(group_id) == "" ->
          {:noreply, socket |> put_flash(:error, "Invalid group")}

        group_id == "Main" ->
          {:noreply, socket |> put_flash(:error, "Cannot delete the Main group")}

        true ->
          # Verify the vertex exists and is a compound (group) node
          case GraphManager.vertex_label(socket.assigns.graph_id, group_id) do
            %{} = group_label ->
              cond do
                Map.get(group_label, :deleted, false) ->
                  {:noreply, socket |> put_flash(:error, "Group not found")}

                not Map.get(group_label, :compound, false) ->
                  {:noreply,
                   socket |> put_flash(:error, "Only groups can be deleted from streams")}

                true ->
                  # Verify the group is empty before deleting
                  all_vertices = GraphManager.vertices(socket.assigns.graph_id)

                  has_children =
                    Enum.any?(all_vertices, fn vid ->
                      vid != group_id and
                        case GraphManager.vertex_label(socket.assigns.graph_id, vid) do
                          %{} = lbl ->
                            Map.get(lbl, :parent) == group_id and
                              not Map.get(lbl, :deleted, false)

                          _ ->
                            false
                        end
                    end)

                  if has_children do
                    {:noreply,
                     socket |> put_flash(:error, "Cannot delete a group that has nodes")}
                  else
                    GraphManager.delete_node(socket.assigns.graph_id, group_id)
                    GraphManager.save_graph(socket.assigns.graph_id)

                    {:noreply,
                     socket
                     |> assign(
                       work_streams: list_streams(socket.assigns.graph_id),
                       f_graph: GraphManager.format_graph_json(socket.assigns.graph_id)
                     )
                     |> put_flash(:info, "Group deleted")}
                  end
              end

            _ ->
              {:noreply, socket |> put_flash(:error, "Group not found")}
          end
      end
    end
  end

  def handle_event("update_exploration_progress", params, socket) do
    {:noreply, assign(socket, :exploration_stats, params)}
  end

  # ── Presentation mode events ──────────────────────────────────────

  def handle_event("enter_presentation_setup", _params, socket) do
    # Toggle: if already in setup, close the panel; otherwise open it
    if socket.assigns.presentation_mode == :setup do
      socket =
        socket
        |> assign(presentation_mode: :off)
        |> push_event("presentation_clear_slides", %{})

      {:noreply, socket}
    else
      # Auto-populate the title with the graph's starting question if not already set
      socket =
        if socket.assigns.presentation_title == "" do
          assign(socket, presentation_title: socket.assigns.graph_struct.title)
        else
          socket
        end

      socket =
        socket
        |> assign(presentation_mode: :setup)
        |> push_presentation_highlights()
        |> push_presentation_persistence()

      {:noreply, socket}
    end
  end

  def handle_event("exit_presentation", params, socket) do
    socket =
      socket
      |> assign(presentation_mode: :off)
      |> push_event("presentation_unfilter_graph", %{})
      |> push_event("toggle_site_header", %{visible: true})
      |> maybe_clear_presentation(params)
      |> push_presentation_persistence()

    {:noreply, socket}
  end

  def handle_event("close_presentation_setup", _params, socket) do
    # Just hide the panel and clear badge overlays — keep the slide deck intact
    socket =
      socket
      |> assign(presentation_mode: :off)
      |> push_event("presentation_clear_slides", %{})

    {:noreply, socket}
  end

  def handle_event("update_presentation_title", %{"title" => title}, socket) do
    title = String.slice(title, 0, 120)

    socket =
      socket
      |> assign(presentation_title: title)
      |> push_presentation_persistence()

    {:noreply, socket}
  end

  def handle_event(
        "restore_presentation",
        %{"slide_ids" => ids, "title" => title},
        socket
      )
      when is_list(ids) and is_binary(title) do
    # Only restore if we don't already have slides (i.e. fresh mount)
    if socket.assigns.presentation_slide_ids == [] do
      # Validate that the IDs actually exist in this graph
      valid_ids =
        Enum.filter(ids, fn id ->
          GraphActions.find_node(socket.assigns.graph_id, id) != nil
        end)

      socket =
        socket
        |> assign(
          presentation_slide_ids: valid_ids,
          presentation_title: String.slice(title, 0, 120)
        )

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  def handle_event("restore_presentation", _params, socket), do: {:noreply, socket}

  def handle_event("presentation_remove_slide", %{"node-id" => node_id}, socket) do
    updated_ids = List.delete(socket.assigns.presentation_slide_ids, node_id)

    socket =
      socket
      |> assign(presentation_slide_ids: updated_ids)
      |> push_presentation_highlights()
      |> push_presentation_persistence()

    {:noreply, socket}
  end

  def handle_event("presentation_reorder", %{"order" => order}, socket) when is_list(order) do
    current_ids = socket.assigns.presentation_slide_ids || []
    allowed_ids = MapSet.new(current_ids)

    sanitized_order =
      order
      |> Enum.uniq()
      |> Enum.filter(&MapSet.member?(allowed_ids, &1))

    socket =
      socket
      |> assign(presentation_slide_ids: sanitized_order)
      |> push_presentation_highlights()
      |> push_presentation_persistence()

    {:noreply, socket}
  end

  def handle_event("presentation_clear_slides", _params, socket) do
    socket =
      socket
      |> assign(presentation_slide_ids: [], presentation_title: "")
      |> push_event("presentation_clear_slides", %{})

    {:noreply, socket}
  end

  def handle_event("start_presenting", _params, socket) do
    ids = socket.assigns.presentation_slide_ids

    if length(ids) > 0 do
      # Ensure the title defaults to the graph's starting question
      title =
        if socket.assigns.presentation_title == "",
          do: socket.assigns.graph_struct.title,
          else: socket.assigns.presentation_title

      # Filter the graph to show only the selected nodes (no full-screen overlay)
      socket =
        socket
        |> assign(presentation_mode: :presenting, presentation_title: title)
        |> push_event("presentation_clear_slides", %{})
        |> push_event("presentation_filter_graph", %{ids: ids})
        |> push_event("toggle_site_header", %{visible: false})
        |> push_presentation_persistence()

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  # ── Combine mode events ──────────────────────────────────────────

  def handle_event("close_combine_setup", _params, socket) do
    socket =
      socket
      |> assign(combine_mode: :off, combine_selected_nodes: [])
      |> push_event("combine_clear_highlights", %{})

    {:noreply, socket}
  end

  def handle_event("combine_deselect_node", %{"node-id" => node_id}, socket) do
    updated_selected =
      Enum.reject(socket.assigns.combine_selected_nodes, fn n -> n.id == node_id end)

    socket =
      socket
      |> assign(combine_selected_nodes: updated_selected)
      |> push_event("combine_highlight_nodes", %{ids: Enum.map(updated_selected, & &1.id)})

    {:noreply, socket}
  end

  def handle_event("combine_clear_selection", _params, socket) do
    socket =
      socket
      |> assign(combine_selected_nodes: [])
      |> push_event("combine_clear_highlights", %{})

    {:noreply, socket}
  end

  def handle_event("execute_combine", _params, socket) do
    if !socket.assigns.can_edit do
      {:noreply, socket |> put_flash(:error, "This graph is locked")}
    else
      case socket.assigns.combine_selected_nodes do
        [node1, node2] ->
          # Execute the combine action
          case GraphActions.combine(
                 graph_action_params(socket, node1),
                 node2.id
               ) do
            nil ->
              {:noreply,
               socket
               |> put_flash(
                 :error,
                 "Unable to combine the selected nodes because one of them no longer exists"
               )}

            node ->
              socket =
                socket
                |> assign(combine_mode: :off, combine_selected_nodes: [])
                |> push_event("combine_clear_highlights", %{})

              update_graph(socket, {nil, node}, "combine")
          end

        _ ->
          {:noreply, socket |> put_flash(:error, "Please select exactly 2 nodes")}
      end
    end
  end

  # ── Private helpers ──────────────────────────────────────────────

  defp maybe_clear_presentation(socket, %{"clear_slides" => value})
       when value in [true, "true"] do
    socket
    |> assign(presentation_slide_ids: [], presentation_title: "")
    |> push_event("presentation_clear_slides", %{})
  end

  defp maybe_clear_presentation(socket, _params), do: socket

  # Handle selection action messages from SelectionActionsComp
  def handle_info({:selection_action, params}, socket) do
    case GraphHelpers.check_selection_action_allowed(socket) do
      {:error, :locked} ->
        {:noreply, socket |> put_flash(:error, "This graph is locked")}

      {:error, :unauthenticated} ->
        {:noreply, assign(socket, show_login_modal: true)}

      :ok ->
        {action, selected_text, node_id, offsets, existing_highlight, extra} =
          GraphHelpers.unpack_selection_action(params)

        handle_selection_action(
          action,
          selected_text,
          node_id,
          offsets,
          existing_highlight,
          extra,
          socket
        )
    end
  end

  def handle_info(:close_share_modal, socket) do
    {:noreply, assign(socket, show_share_modal: false)}
  end

  # Highlight PubSub (:created, :updated, :deleted) injected by GraphStreaming

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

  # :stream_chunk and :stream_chunk_broadcast are injected by GraphStreaming

  def handle_info({:llm_request_complete, node_id}, socket) do
    Logger.debug(fn ->
      "[GraphLive] llm_request_complete node_id=#{inspect(node_id)} current=#{inspect(socket.assigns.node && Map.get(socket.assigns.node, :id))}"
    end)

    # Regenerate f_graph now that streaming is complete to ensure graph structure is up-to-date
    socket =
      socket
      |> assign(streaming_nodes: MapSet.delete(socket.assigns.streaming_nodes, node_id))
      |> assign(work_streams: list_streams(socket.assigns.graph_id))
      |> assign(f_graph: GraphManager.format_graph_json(socket.assigns.graph_id))

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
      label = NodeTitleHelper.extract_node_title(updated_vertex)

      socket =
        socket
        |> assign(node: updated_vertex)
        |> push_event("update_node_label", %{id: node_id, label: label})

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  defp handle_selection_action(
         :explain,
         selected_text,
         node_id,
         offsets,
         existing_highlight,
         _params,
         socket
       ) do
    highlight = existing_highlight || create_highlight(socket, node_id, offsets, selected_text)

    if highlight do
      # Create the question/answer sequence
      {_graph, answer_node} =
        GraphActions.ask_and_answer(
          graph_action_params(socket, socket.assigns.node),
          "Please explain: #{selected_text}",
          minimal_context: true
        )

      # Link the highlight to the answer node using new link system
      if answer_node do
        Highlights.add_link(highlight.id, answer_node.id, "explain")
      end

      update_graph(socket, {nil, answer_node}, "answer")
    else
      # If highlight creation fails, still create the nodes
      update_graph(
        socket,
        GraphActions.ask_and_answer(
          graph_action_params(socket, socket.assigns.node),
          "Please explain: #{selected_text}",
          minimal_context: true
        ),
        "answer"
      )
    end
  end

  defp handle_selection_action(
         :highlight_only,
         selected_text,
         node_id,
         offsets,
         existing_highlight,
         _params,
         socket
       ) do
    if existing_highlight do
      # Highlight already exists, just close modal
      {:noreply, socket}
    else
      # Create new highlight without any linked nodes
      _highlight = create_highlight(socket, node_id, offsets, selected_text)
      {:noreply, socket}
    end
  end

  defp handle_selection_action(
         :pros_cons,
         selected_text,
         node_id,
         offsets,
         existing_highlight,
         _params,
         socket
       ) do
    highlight = existing_highlight || create_highlight(socket, node_id, offsets, selected_text)

    # Create pros/cons branches
    parent_node = GraphActions.find_node(socket.assigns.graph_id, node_id)
    GraphActions.branch(graph_action_params(socket, parent_node), content_override: selected_text)

    # Store highlight ID for linking after graph updates
    socket =
      if highlight do
        assign(socket, pending_link_highlight_id: highlight.id, pending_link_parent_id: node_id)
      else
        socket
      end

    {:noreply, updated_socket} = update_graph(socket, {nil, parent_node}, "branch")
    {:noreply, create_pending_highlight_links(updated_socket)}
  end

  defp handle_selection_action(
         :related_ideas,
         selected_text,
         node_id,
         offsets,
         existing_highlight,
         _params,
         socket
       ) do
    highlight = existing_highlight || create_highlight(socket, node_id, offsets, selected_text)

    if highlight do
      # Create related ideas node
      parent_node = GraphActions.find_node(socket.assigns.graph_id, node_id)

      ideas_node =
        GraphActions.related_ideas(graph_action_params(socket, parent_node),
          content_override: selected_text
        )

      # Link highlight to the ideas node
      if ideas_node do
        Highlights.add_link(highlight.id, ideas_node.id, "related_idea")
      end

      update_graph(socket, {nil, ideas_node}, "ideas")
    else
      # If highlight creation fails, still create the ideas node
      parent_node = GraphActions.find_node(socket.assigns.graph_id, node_id)

      update_graph(
        socket,
        {nil,
         GraphActions.related_ideas(graph_action_params(socket, parent_node),
           content_override: selected_text
         )},
        "ideas"
      )
    end
  end

  defp handle_selection_action(
         :ask_question,
         selected_text,
         node_id,
         offsets,
         existing_highlight,
         %{question: question_text},
         socket
       ) do
    highlight = existing_highlight || create_highlight(socket, node_id, offsets, selected_text)

    if highlight do
      # Create the question/answer sequence
      {_graph, answer_node} =
        GraphActions.ask_about_selection(
          graph_action_params(socket, socket.assigns.node),
          "#{question_text}\n\nRegarding: \"#{selected_text}\"",
          selected_text
        )

      # Link the highlight to the answer node using new link system
      if answer_node do
        Highlights.add_link(highlight.id, answer_node.id, "question")
      end

      update_graph(socket, {nil, answer_node}, "answer")
    else
      # If highlight creation fails, still create the nodes
      update_graph(
        socket,
        GraphActions.ask_about_selection(
          graph_action_params(socket, socket.assigns.node),
          "#{question_text}\n\nRegarding: \"#{selected_text}\"",
          selected_text
        ),
        "answer"
      )
    end
  end

  defp handle_selection_action(
         :comment,
         selected_text,
         node_id,
         offsets,
         existing_highlight,
         %{comment: comment_text},
         socket
       ) do
    highlight = existing_highlight || create_highlight(socket, node_id, offsets, selected_text)
    parent_node = GraphActions.find_node(socket.assigns.graph_id, node_id)

    full_comment = "#{comment_text}\n\nRegarding: \"#{selected_text}\""

    comment_node =
      GraphActions.comment(
        graph_action_params(socket, parent_node),
        full_comment
      )

    if comment_node do
      GraphManager.update_vertex_fields(socket.assigns.graph_id, comment_node.id, %{
        source_text: selected_text
      })

      if highlight do
        Highlights.add_link(highlight.id, comment_node.id, "comment")
      end
    end

    update_graph(socket, {nil, comment_node}, "user")
  end

  defp create_pending_highlight_links(socket) do
    highlight_id = socket.assigns[:pending_link_highlight_id]
    parent_id = socket.assigns[:pending_link_parent_id]

    Logger.debug(
      "[create_pending_highlight_links] Called with highlight_id=#{inspect(highlight_id)}, parent_id=#{inspect(parent_id)}"
    )

    if highlight_id && parent_id do
      # Re-fetch parent to get newly created children
      parent_node = GraphActions.find_node(socket.assigns.graph_id, parent_id)

      Logger.debug(
        "[create_pending_highlight_links] Parent node: #{inspect(parent_node && parent_node.id)}, children count: #{inspect(parent_node && length(parent_node.children || []))}"
      )

      Logger.debug(
        "[create_pending_highlight_links] All children: #{inspect(parent_node && parent_node.children)}"
      )

      if parent_node && parent_node.children do
        # Get the two most recent children (thesis and antithesis)
        recent_children = Enum.take(parent_node.children, -2)

        Logger.debug(
          "[create_pending_highlight_links] Recent children (last 2): #{inspect(recent_children |> Enum.map(& &1.id))}"
        )

        Enum.each(recent_children, fn child_node ->
          Logger.debug(
            "[create_pending_highlight_links] Processing child node: #{inspect(child_node.id)}, class: #{inspect(child_node.class)}"
          )

          link_type =
            case child_node.class do
              "thesis" -> "pro"
              "antithesis" -> "con"
              _ -> nil
            end

          Logger.debug(
            "[create_pending_highlight_links] Link type for #{child_node.id}: #{inspect(link_type)}"
          )

          if link_type do
            result = Highlights.add_link(highlight_id, child_node.id, link_type)
            Logger.debug("[create_pending_highlight_links] add_link result: #{inspect(result)}")
          end
        end)
      end

      # Clear pending link data
      assign(socket, pending_link_highlight_id: nil, pending_link_parent_id: nil)
    else
      socket
    end
  end

  defp create_highlight(socket, node_id, offsets, selected_text) do
    highlight_attrs = %{
      mudg_id: socket.assigns.graph_id,
      node_id: node_id,
      text_source_type: "node",
      selection_start: offsets["start"],
      selection_end: offsets["end"],
      selected_text_snapshot: selected_text,
      created_by_user_id: socket.assigns.current_user.id
    }

    case Highlights.create_highlight(highlight_attrs) do
      {:ok, highlight} -> highlight
      {:error, _changeset} -> nil
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
    GraphHelpers.graph_action_params(socket, node)
  end

  defp compute_nav_flags(_graph, nil), do: {false, false, false, false}

  defp compute_nav_flags(graph, node) do
    can_up = is_list(node.parents) and List.first(node.parents) != nil
    can_down = is_list(node.children) and List.first(node.children) != nil

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
            if Map.get(v, :compound) == true and not Map.get(v, :deleted, false) do
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

    # Clear search when a node is clicked from search results
    socket =
      if operation == "node_clicked" and socket.assigns.search_term != "" do
        assign(socket, search_term: "", search_results: [])
      else
        socket
      end

    {nav_up, nav_down, nav_left, nav_right} = compute_nav_flags(socket.assigns.graph_id, node)

    # Skip f_graph regeneration for content-only updates to prevent stuttering
    # Structural operations (new nodes/edges) must regenerate so Cytoscape stays in sync
    content_only_operations = ["llm_request_complete"]

    new_socket =
      assign(socket,
        f_graph:
          if operation in content_only_operations do
            socket.assigns.f_graph
          else
            GraphManager.format_graph_json(socket.assigns.graph_id)
          end,
        form:
          if operation in ["llm_request_complete"] do
            socket.assigns.form
          else
            to_form(changeset, id: new_node.id)
          end,
        node: node,
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
      |> then(fn s ->
        # Reset the side-drawer scroll position when navigating to a
        # different node.  Skip streaming updates — those append content
        # to the current node and shouldn't jump the user back to top.
        if operation not in ["llm_request_complete"] do
          push_event(s, "scroll_to_top", %{})
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

  defp update_streaming_node(socket, updated_vertex, node_id) do
    new_content = Map.get(updated_vertex, :content, "")

    # Check if we've already set the title for this node on this socket
    already_titled = MapSet.member?(socket.assigns.titled_nodes, node_id)
    new_title = NodeTitleHelper.extract_node_title(updated_vertex)
    needs_title_set = !already_titled && new_title != ""

    # Push label update to Cytoscape for all users, regardless of which node they're viewing
    socket =
      if needs_title_set do
        socket
        |> assign(titled_nodes: MapSet.put(socket.assigns.titled_nodes, node_id))
        |> push_event("update_node_label", %{id: node_id, label: new_title})
      else
        socket
      end

    # If this user is currently viewing the streaming node, update their assigns
    if socket.assigns.node && node_id == Map.get(socket.assigns.node, :id) do
      current_content = Map.get(socket.assigns.node, :content, "")

      # Skip assign update if content hasn't changed
      if current_content == new_content do
        socket
      else
        # Merge content update while preserving relatives (parents/children)
        node = %{socket.assigns.node | content: new_content}
        assign(socket, node: node)
      end
    else
      socket
    end
  end

  defp fetch_graph(user, graph_id, params) do
    # Try slug first, then title for backward compatibility
    case Dialectic.DbActions.Graphs.get_graph_by_slug_or_title(graph_id) do
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
            # Always use title for GraphManager lookup (internal identifier)
            {:ok, GraphManager.get_graph(graph_db.title), graph_db}
          rescue
            _e ->
              require Logger
              Logger.error("Failed to load graph: #{graph_db.title}")
              {:error, "Error loading graph: #{graph_db.title}"}
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
      titled_nodes: MapSet.new(),
      graph_operation: "",
      ask_question: true,
      group_states: %{},
      search_term: "",
      search_results: [],
      show_search_overlay: false,
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
      highlights: [],
      presentation_mode: :off,
      presentation_slide_ids: [],
      presentation_title: "",
      combine_mode: :off,
      combine_selected_nodes: [],
      graph_owner_name: nil
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

      # Load highlights asynchronously after connection - doesn't block initial render
      highlights = Highlights.list_highlights_with_links(mudg_id: graph_id)

      socket
      |> stream(:presences, presences)
      |> assign(highlights: highlights)
      |> push_event("highlights_loaded", %{
        highlights: serialize_highlights(highlights)
      })
    else
      # Load highlights even when not connected (e.g., during tests or initial render)
      highlights = Highlights.list_highlights_with_links(mudg_id: graph_id)

      socket
      |> stream(:presences, [])
      |> assign(highlights: highlights)
    end
  end

  defp serialize_highlights(highlights) do
    Enum.map(highlights, fn h ->
      %{
        id: h.id,
        node_id: h.node_id,
        selection_start: h.selection_start,
        selection_end: h.selection_end,
        selected_text_snapshot: h.selected_text_snapshot,
        links:
          Enum.map(h.links || [], fn l ->
            %{node_id: l.node_id, link_type: l.link_type}
          end)
      }
    end)
  end

  defp assign_graph_data(socket, graph_db, graph_struct, node, graph_id, user) do
    changeset = GraphActions.create_new_node(user) |> Vertex.changeset()
    can_edit = !graph_struct.is_locked
    {nav_up, nav_down, nav_left, nav_right} = compute_nav_flags(graph_id, node)

    base_url = DialecticWeb.Endpoint.url()
    canonical = base_url <> "/g/#{graph_struct.slug}"

    description =
      "Explore the interactive grid for \"#{graph_struct.title}\". Visualize arguments, discover connections, and collaborate on RationalGrid."

    # JSON-LD structured data for search engine rich results
    json_ld =
      Jason.encode!(%{
        "@context" => "https://schema.org",
        "@type" => "Article",
        "name" => graph_struct.title,
        "headline" => graph_struct.title,
        "description" => description,
        "url" => canonical,
        "image" => base_url <> ~p"/images/graph_live.webp",
        "dateModified" => DateTime.to_iso8601(graph_struct.updated_at),
        "datePublished" => DateTime.to_iso8601(graph_struct.inserted_at),
        "publisher" => %{
          "@type" => "Organization",
          "name" => "RationalGrid",
          "url" => base_url
        },
        "keywords" => graph_struct.tags || [],
        "isAccessibleForFree" => true
      })

    # Resolve the graph owner's display name for presentation credits
    owner_name =
      case graph_db.user_id do
        nil ->
          nil

        uid ->
          case Repo.get(User, uid) do
            nil -> nil
            user -> User.display_name(user)
          end
      end

    assign(socket,
      page_title: graph_struct.title,
      graph_owner_name: owner_name,
      og_image: base_url <> ~p"/images/graph_live.webp",
      page_description: description,
      canonical_url: canonical,
      og_type: "article",
      json_ld: json_ld,
      noindex: !graph_struct.is_public,
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
      prompt_mode: Atom.to_string(Dialectic.Responses.ModeServer.get_mode(graph_id))
    )
  end

  defp handle_initial_highlight(socket, highlight_id) do
    if connected?(socket) && highlight_id do
      push_event(socket, "scroll_to_highlight", %{id: highlight_id})
    else
      socket
    end
  end

  # ── Presentation helpers ────────────────────────────────────────────

  defp push_presentation_highlights(socket) do
    ids = socket.assigns.presentation_slide_ids
    push_event(socket, "presentation_highlight_slides", %{ids: ids})
  end

  defp push_presentation_persistence(socket) do
    graph_id = socket.assigns.graph_id

    push_event(socket, "presentation_persist", %{
      graph_id: graph_id,
      slide_ids: socket.assigns.presentation_slide_ids,
      title: socket.assigns.presentation_title
    })
  end

  defp presentation_slides(%{graph_id: graph_id, presentation_slide_ids: ids}) do
    ids
    |> Enum.reduce([], fn id, acc ->
      case GraphActions.find_node(graph_id, id) do
        nil -> acc
        node -> [node | acc]
      end
    end)
    |> Enum.reverse()
  end
end
