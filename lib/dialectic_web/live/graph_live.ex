defmodule DialecticWeb.GraphLive do
  use DialecticWeb, :live_view

  alias Dialectic.Graph.{Vertex, GraphActions, Siblings}
  alias DialecticWeb.{CombineComp, NodeComp}
  alias Dialectic.DbActions.DbWorker
  alias Dialectic.DbActions.Graphs
  alias DialecticWeb.Utils.UserUtils

  alias Phoenix.PubSub

  require Logger

  on_mount {DialecticWeb.UserAuth, :mount_current_user}

  def mount(%{"graph_name" => graph_id_uri} = params, _session, socket) do
    graph_id = URI.decode(graph_id_uri)

    # Honor ?mode=... param by persisting per-graph mode before any actions
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

    live_view_topic = "graph_update:#{socket.id}"
    graph_topic = "graph_update:#{graph_id}"

    user = UserUtils.current_identity(socket.assigns)

    node_id = Map.get(params, "node", "1")

    socket = stream(socket, :presences, [])

    socket =
      if connected?(socket) do
        # Subscribe to the liveview events and the graph wide events
        Phoenix.PubSub.subscribe(Dialectic.PubSub, live_view_topic)
        Phoenix.PubSub.subscribe(Dialectic.PubSub, graph_topic)
        DialecticWeb.Presence.track_user(user, %{id: user, graph_id: graph_id})
        DialecticWeb.Presence.subscribe()

        presences =
          DialecticWeb.Presence.list_online_users(graph_id)

        stream(socket, :presences, presences)
      else
        socket
      end

    # Check if the graph exists in the database before trying to get it
    case Dialectic.DbActions.Graphs.get_graph_by_title(graph_id) do
      nil ->
        # If the graph doesn't exist, redirect to homepage with error
        socket =
          socket
          |> put_flash(:error, "Graph not found: #{graph_id}")
          |> redirect(to: ~p"/")

        {:ok, socket}

      _graph_exists ->
        # Try to get the graph safely
        result =
          try do
            {:ok, GraphManager.get_graph(graph_id)}
          rescue
            _e ->
              # If there's an error fetching it, redirect home instead of creating a new graph
              require Logger
              Logger.error("Failed to load graph: #{graph_id}")
              {:error, "Error loading graph: #{graph_id}"}
          end

        case result do
          {:ok, {graph_struct, graph}} ->
            # Continue with the normal flow

            # Ensure a main group exists to make root togglable
            graph = ensure_main_group(graph_id, graph)

            # Handle case when the node might not exist
            node =
              case :digraph.vertex(graph, node_id) do
                {_, vertex} ->
                  Vertex.add_relatives(vertex, graph)

                _ ->
                  # Default to node "1" if specified node doesn't exist
                  case :digraph.vertex(graph, "1") do
                    {_, default_vertex} -> Vertex.add_relatives(default_vertex, graph)
                    _ -> default_node()
                  end
              end

            changeset = GraphActions.create_new_node(user) |> Vertex.changeset()

            # TODO - can edit is going to be expaned to be more complex, but for the time being, just is not protected
            can_edit = graph_struct.is_public
            {nav_up, nav_down, nav_left, nav_right} = compute_nav_flags(graph_id, node)

            socket =
              assign(socket,
                live_view_topic: live_view_topic,
                graph_topic: graph_topic,
                graph_struct: graph_struct,
                graph_id: graph_id,
                f_graph: GraphManager.format_graph_json(graph_id),
                node: node,
                form: to_form(changeset),
                show_combine: false,
                user: user,
                current_user: socket.assigns[:current_user],
                can_edit: can_edit,
                node_menu_visible: true,
                drawer_open: true,
                right_panel_open: false,
                bottom_menu_open: true,
                graph_operation: "",
                ask_question: true,
                group_states: %{},
                search_term: "",
                search_results: [],
                nav_can_up: nav_up,
                nav_can_down: nav_down,
                nav_can_left: nav_left,
                nav_can_right: nav_right,
                open_read_modal: false,
                show_explore_modal: false,
                explore_items: [],
                explore_selected: [],
                show_start_stream_modal: false,
                work_streams: list_streams(graph_id),
                prompt_mode: Atom.to_string(Dialectic.Responses.ModeServer.get_mode(graph_id))
              )

            ask_param_raw = Map.get(params, "ask")

            ask_param =
              if is_binary(ask_param_raw),
                do: URI.decode(String.replace(ask_param_raw, "+", " ")),
                else: ask_param_raw

            socket =
              if connected?(socket) and is_binary(ask_param) and String.trim(ask_param) != "" do
                result =
                  GraphActions.ask_and_answer_origin(graph_action_params(socket, node), ask_param)

                case result do
                  {_, node} ->
                    {_, s1} = update_graph(socket, {nil, node}, "answer")
                    s1

                  _ ->
                    Logger.warning(
                      "ask_and_answer_origin returned unexpected: #{inspect(result)}"
                    )

                    socket
                end
              else
                socket
              end

            {:ok, socket}

          {:error, error_message} ->
            # Redirect to home with the error message
            socket =
              socket
              |> put_flash(:error, error_message)
              |> redirect(to: ~p"/")

            {:ok, socket}
        end
    end
  end

  def mount(params, _session, socket) do
    user = UserUtils.current_identity(socket.assigns)
    changeset = GraphActions.create_new_node(user) |> Vertex.changeset()

    # Derive initial prompt mode from query param (?mode=creative) when no graph exists yet
    initial_mode_str =
      case params do
        %{"mode" => mode} when is_binary(mode) ->
          case String.downcase(mode) do
            "creative" -> "creative"
            _ -> "structured"
          end

        _ ->
          "structured"
      end

    {:ok,
     assign(socket,
       live_view_topic: "graph_update:#{socket.id}",
       graph_topic: nil,
       graph_struct: nil,
       graph_id: nil,
       f_graph: format_graph(nil),
       node: %{
         id: "start",
         content: "# Ask a question to get started\nType a question below to create a new graph.",
         children: [],
         parents: []
       },
       form: to_form(changeset),
       show_combine: false,
       user: user,
       current_user: socket.assigns[:current_user],
       can_edit: true,
       node_menu_visible: false,
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
       work_streams: [],
       prompt_mode: initial_mode_str
     )}
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
    can_edit = graph_struct.is_public
    {:noreply, socket |> assign(graph_struct: graph_struct, can_edit: can_edit)}
  end

  def handle_event("note", %{"node" => node_id}, socket) do
    if socket.assigns.current_user == nil do
      {:noreply, socket |> put_flash(:error, "You must be logged in to note")}
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
      {:noreply, socket |> put_flash(:error, "You must be logged in to unnote")}
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
        {:noreply, socket |> put_flash(:error, "You must be logged in to delete nodes")}
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
                {_, graph2} = GraphManager.get_graph(socket.assigns.graph_id)

                # Ensure we navigate to a valid, non-deleted node.
                # If no parent exists or it's invalid/deleted, pick the first non-deleted node in the graph.
                selected_node =
                  cond do
                    is_map(next_node) and not Map.get(next_node, :deleted, false) ->
                      Vertex.add_relatives(next_node, graph2)

                    true ->
                      fallback =
                        Enum.find_value(:digraph.vertices(graph2), fn vid ->
                          case :digraph.vertex(graph2, vid) do
                            {^vid, v} ->
                              if not Map.get(v, :deleted, false), do: v, else: nil

                            _ ->
                              nil
                          end
                        end)

                      if fallback do
                        Vertex.add_relatives(fallback, graph2)
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

  def handle_event("node_move", %{"direction" => direction}, socket) do
    {:noreply, updated_socket} =
      update_graph(
        socket,
        {nil, GraphActions.move(graph_action_params(socket), direction)},
        "node_clicked"
      )

    # Preserve and re-apply panel/menu state across node moves
    updated_socket = reapply_right_panel_state(socket, updated_socket)

    {:noreply, push_event(updated_socket, "center_node", %{id: updated_socket.assigns.node.id})}
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
      # If we're on the empty home state (no graph yet), create a new graph and redirect to it
      is_nil(socket.assigns[:graph_id]) ->
        title = sanitize_graph_title(answer)

        case Graphs.create_new_graph(title, socket.assigns[:current_user]) do
          {:ok, _graph} ->
            mode_q = socket.assigns[:prompt_mode] || "structured"

            {:noreply,
             socket
             |> redirect(
               to: ~p"/#{title}?node=1&ask=#{URI.encode_www_form(answer)}&mode=#{mode_q}"
             )}

          {:error, _changeset} ->
            {:noreply, socket |> put_flash(:error, "Error creating graph")}
        end

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

      if Map.get(params, "auto_answer") in ["on", "true", "1"] do
        GraphActions.answer(graph_action_params(socket, node2))
      end

      update_graph(socket, {nil, node2}, "start_stream")
    end
  end

  def handle_event("focus_stream", %{"id" => group_id}, socket) do
    {:noreply, push_event(socket, "focus_group", %{id: group_id})}
  end

  def handle_event("toggle_stream", %{"id" => group_id}, socket) do
    {:noreply, push_event(socket, "toggle_group", %{id: group_id})}
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
    if self() != sender_pid do
      {_graph_struct, _graph} = GraphManager.get_graph(socket.assigns.graph_id)

      {:noreply,
       assign(socket,
         f_graph: GraphManager.format_graph_json(socket.assigns.graph_id),
         graph_operation: "other_user_change",
         work_streams: list_streams(socket.assigns.graph_id)
       )}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:stream_chunk, updated_vertex, :node_id, node_id}, socket) do
    # This is the streamed LLM response into a node

    if socket.assigns.node && node_id == Map.get(socket.assigns.node, :id) do
      {:noreply, assign(socket, node: updated_vertex)}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:llm_request_complete, node_id}, socket) do
    # Workers already finalize node content; proceed to broadcast update
    # Broadcast new node to all connected users
    PubSub.broadcast(
      Dialectic.PubSub,
      socket.assigns.graph_topic,
      {:other_user_change, self()}
    )

    update_graph(
      socket,
      {nil, GraphActions.find_node(socket.assigns.graph_id, node_id)},
      "llm_request_complete"
    )
  end

  def handle_info({:stream_error, error, :node_id, node_id}, socket) do
    # This is the streamed LLM response into a node
    # TODO - broadcast to all users??? - only want to update the node that is being worked on, just rerender the others
    updated_vertex = GraphManager.update_vertex(socket.assigns.graph_id, node_id, error)

    if socket.assigns.node && node_id == Map.get(socket.assigns.node, :id) do
      {:noreply, assign(socket, node: updated_vertex)}
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

  defp ensure_main_group(graph_id, graph) do
    try do
      # If a Main compound group exists, do nothing
      case GraphManager.vertex_label(graph_id, "Main") do
        %{} ->
          graph

        _ ->
          # Collect all top-level nodes (non-compound and no parent)
          child_ids =
            GraphManager.vertices(graph_id)
            |> Enum.filter(fn vid ->
              case GraphManager.vertex_label(graph_id, vid) do
                %{} = v ->
                  Map.get(v, :compound, false) != true and is_nil(Map.get(v, :parent))

                _ ->
                  false
              end
            end)

          # Create the Main group and assign children
          updated = GraphManager.create_group(graph_id, "Main", child_ids)
          DbWorker.save_graph(graph_id)
          updated
      end
    rescue
      _ -> graph
    end
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
             "explain"
           ] &&
             node && Map.get(node, :id) do
          push_event(s, "center_node", %{id: node.id})
        else
          s
        end
      end)

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
end
