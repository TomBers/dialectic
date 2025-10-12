defmodule DialecticWeb.GraphLive do
  use DialecticWeb, :live_view

  alias Dialectic.Graph.{Vertex, GraphActions, Siblings}
  alias DialecticWeb.{CombineComp, NodeComp}
  alias Dialectic.DbActions.DbWorker
  alias DialecticWeb.Utils.UserUtils

  alias Phoenix.PubSub

  on_mount {DialecticWeb.UserAuth, :mount_current_user}

  def mount(%{"graph_name" => graph_id_uri} = params, _session, socket) do
    graph_id = URI.decode(graph_id_uri)

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
            {nav_up, nav_down, nav_left, nav_right} = compute_nav_flags(graph, node)

            {:ok,
             assign(socket,
               live_view_topic: live_view_topic,
               graph_topic: graph_topic,
               graph_struct: graph_struct,
               graph_id: graph_id,
               graph: graph,
               f_graph: format_graph(graph),
               node: node,
               form: to_form(changeset),
               show_combine: false,
               user: user,
               current_user: socket.assigns[:current_user],
               can_edit: can_edit,
               node_menu_visible: true,
               drawer_open: true,
               graph_operation: "",
               ask_question: true,
               open_sections: %{
                 "search" => true,
                 "lock" => false,
                 "node_info" => false,
                 "streams" => false,
                 "shortcuts" => false
               },
               group_states: %{},
               search_term: "",
               search_results: [],
               nav_can_up: nav_up,
               nav_can_down: nav_down,
               nav_can_left: nav_left,
               nav_can_right: nav_right,
               open_read_modal: Map.has_key?(params, "node"),
               show_explore_modal: false,
               explore_items: [],
               explore_selected: [],
               show_start_stream_modal: false,
               work_streams: list_streams(graph)
             )}

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

  defp default_node do
    %{id: "1", content: "", children: [], parents: []}
  end

  def handle_event("node:join_group", %{"node" => nid, "parent" => gid}, socket) do
    graph = GraphManager.set_parent(socket.assigns.graph_id, nid, gid)
    DbWorker.save_graph(socket.assigns.graph_id)

    {:noreply,
     socket
     |> assign(
       graph: graph,
       f_graph: format_graph(graph),
       graph_operation: "join_group"
     )}
  end

  def handle_event("node:leave_group", %{"node" => nid}, socket) do
    # Server-side guard: do not allow leaving if it would leave the group empty
    {_gs, g} = GraphManager.get_graph(socket.assigns.graph_id)

    case :digraph.vertex(g, nid) do
      {^nid, v} ->
        parent_id = Map.get(v, :parent)

        if is_binary(parent_id) do
          children_count =
            :digraph.vertices(g)
            |> Enum.count(fn vid ->
              case :digraph.vertex(g, vid) do
                {^vid, lbl} -> Map.get(lbl, :parent) == parent_id
                _ -> false
              end
            end)

          if children_count <= 1 do
            # Block leaving the last child; no-op
            {:noreply, socket}
          else
            graph = GraphManager.remove_parent(socket.assigns.graph_id, nid)
            DbWorker.save_graph(socket.assigns.graph_id)

            {:noreply,
             socket
             |> assign(
               graph: graph,
               f_graph: format_graph(graph),
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

  # Handle form submission and change events
  def handle_event("search_nodes", params, socket) do
    search_term = params["search_term"] || params["value"] || ""

    if search_term == "" do
      {:noreply, socket |> assign(search_term: "", search_results: [])}
    else
      search_results = search_graph_nodes(socket.assigns.graph, search_term)
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
        GraphActions.change_noted_by(
          graph_action_params(socket),
          node_id,
          &Vertex.add_noted_by/2
        ),
        "note"
      )
    end
  end

  def handle_event("toggle_node_menu", _, socket) do
    {:noreply,
     socket
     |> assign(:node_menu_visible, !socket.assigns.node_menu_visible)}
  end

  def handle_event("toggle_section", %{"section" => section}, socket) do
    open_sections = socket.assigns[:open_sections] || %{}
    current = Map.get(open_sections, section, false)
    new_sections = Map.put(open_sections, section, !current)

    socket = assign(socket, :open_sections, new_sections)

    send_update(DialecticWeb.RightPanelComp,
      id: "right-panel-comp",
      open_sections: new_sections
    )

    {:noreply, socket}
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
        GraphActions.change_noted_by(
          graph_action_params(socket),
          node_id,
          &Vertex.remove_noted_by/2
        ),
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

          {_graph, node} ->
            children = Map.get(node, :children, [])

            owns = UserUtils.owner?(node, socket.assigns)

            cond do
              not owns ->
                {:noreply, socket |> put_flash(:error, "You can only delete nodes you created")}

              Enum.any?(children, fn ch -> not Map.get(ch, :deleted, false) end) ->
                {:noreply,
                 socket |> put_flash(:error, "Cannot delete a node that has non-deleted children")}

              true ->
                {graph2, next_node} =
                  GraphActions.delete_node(graph_action_params(socket), node_id)

                DbWorker.save_graph(socket.assigns.graph_id)

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
                  update_graph(socket, {graph2, selected_node}, "delete")

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
      items
      |> Enum.each(fn item ->
        GraphActions.answer_selection(
          graph_action_params(socket, socket.assigns.node),
          "Please explain: #{item}",
          "explain"
        )
      end)

      {:noreply, socket |> put_flash(:info, "Exploring all points")}
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
        Enum.each(selected, fn item ->
          GraphActions.answer_selection(
            graph_action_params(socket, socket.assigns.node),
            "Please explain: #{item}",
            "explain"
          )
        end)

        {:noreply,
         socket
         |> put_flash(:info, "Exploring selected points (#{length(selected)})")
         |> assign(show_explore_modal: false, explore_items: [], explore_selected: [])}
      end
    end
  end

  def handle_event("node_branch", %{"id" => node_id}, socket) do
    if !socket.assigns.can_edit do
      {:noreply, socket |> put_flash(:error, "This graph is locked")}
    else
      {_, node} = GraphActions.find_node(socket.assigns.graph_id, node_id)
      # Ensure branching from the correct node
      update_graph(
        socket,
        GraphActions.branch(graph_action_params(socket, node)),
        "branch"
      )
    end
  end

  def handle_event("node_combine", %{"id" => node_id}, socket) do
    if !socket.assigns.can_edit do
      {:noreply, socket |> put_flash(:error, "This graph is locked")}
    else
      {_, node} = GraphActions.find_node(socket.assigns.graph_id, node_id)
      {:noreply, assign(socket, show_combine: true, node: node)}
    end
  end

  def handle_event("node_related_ideas", %{"id" => node_id}, socket) do
    if !socket.assigns.can_edit do
      {:noreply, socket |> put_flash(:error, "This graph is locked")}
    else
      {_, node} = GraphActions.find_node(socket.assigns.graph_id, node_id)

      update_graph(
        socket,
        GraphActions.related_ideas(graph_action_params(socket, node)),
        "ideas"
      )
    end
  end

  def handle_event("combine_node_select", %{"selected_node" => node_id}, socket) do
    if !socket.assigns.can_edit do
      {:noreply, socket |> put_flash(:error, "This graph is locked")}
    else
      {graph, node} =
        GraphActions.combine(
          graph_action_params(socket),
          node_id
        )

      update_graph(socket, {graph, node}, "combine")
    end
  end

  def handle_event("node_clicked", %{"id" => id}, socket) do
    # Determine if this was triggered from search results
    from_search = socket.assigns.search_term != "" and length(socket.assigns.search_results) > 0

    # Update the graph
    {:noreply, updated_socket} =
      update_graph(socket, GraphActions.find_node(socket.assigns.graph_id, id), "node_clicked")

    # Preserve and re-apply panel/menu state across node changes
    updated_socket =
      updated_socket
      |> assign(
        :open_sections,
        socket.assigns[:open_sections] ||
          %{
            "search" => true,
            "lock" => false,
            "node_info" => false,
            "streams" => false,
            "shortcuts" => false
          }
      )
      |> assign(:group_states, socket.assigns[:group_states] || %{})

    send_update(
      DialecticWeb.RightPanelComp,
      id: "right-panel-comp",
      group_states: updated_socket.assigns[:group_states],
      open_sections: updated_socket.assigns[:open_sections]
    )

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
        GraphActions.move(graph_action_params(socket), direction),
        "node_clicked"
      )

    # Preserve and re-apply panel/menu state across node moves
    updated_socket =
      updated_socket
      |> assign(
        :open_sections,
        socket.assigns[:open_sections] ||
          %{
            "search" => true,
            "lock" => false,
            "node_info" => false,
            "streams" => false,
            "shortcuts" => false
          }
      )
      |> assign(:group_states, socket.assigns[:group_states] || %{})

    send_update(
      DialecticWeb.RightPanelComp,
      id: "right-panel-comp",
      group_states: updated_socket.assigns[:group_states],
      open_sections: updated_socket.assigns[:open_sections]
    )

    {:noreply, push_event(updated_socket, "center_node", %{id: updated_socket.assigns.node.id})}
  end

  def handle_event("answer", %{"vertex" => %{"content" => ""}}, socket), do: {:noreply, socket}

  def handle_event("answer", %{"vertex" => %{"content" => answer}}, socket) do
    if socket.assigns.can_edit do
      update_graph(socket, GraphActions.comment(graph_action_params(socket), answer), "comment")
    else
      {:noreply, socket |> put_flash(:error, "This graph is locked")}
    end
  end

  def handle_event("reply-and-answer", %{"vertex" => %{"content" => answer}} = _params, socket) do
    if !socket.assigns.can_edit do
      {:noreply, socket |> put_flash(:error, "This graph is locked")}
    else
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
      {graph2, node2} = GraphManager.find_node_by_id(socket.assigns.graph_id, new_node.id)
      DbWorker.save_graph(socket.assigns.graph_id)

      if Map.get(params, "auto_answer") in ["on", "true", "1"] do
        GraphActions.answer(graph_action_params(socket, node2))
      end

      update_graph(socket, {graph2, node2}, "start_stream")
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
      {_graph_struct, graph} = GraphManager.get_graph(socket.assigns.graph_id)

      {:noreply,
       assign(socket,
         graph: graph,
         f_graph: format_graph(graph),
         graph_operation: "other_user_change",
         work_streams: list_streams(graph)
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
    # Make sure that the graph is saved to the database
    # We pass false so that it does not respect the queue exlusion period and stores the response immediately.

    # Broadcast new node to all connected users
    PubSub.broadcast(
      Dialectic.PubSub,
      socket.assigns.graph_topic,
      {:other_user_change, self()}
    )

    update_graph(
      socket,
      GraphActions.find_node(socket.assigns.graph_id, node_id),
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

  # Search for nodes in the graph based on a search term
  defp search_graph_nodes(graph, search_term) do
    search_term = String.downcase(search_term)

    # Return empty results if graph is invalid
    if is_nil(graph) do
      []
    else
      # Process vertices in a more defensive way
      results =
        try do
          Enum.reduce(:digraph.vertices(graph), [], fn vertex_id, acc ->
            # Get vertex safely
            vertex_data =
              case :digraph.vertex(graph, vertex_id) do
                {^vertex_id, vertex} -> vertex
                _ -> nil
              end

            # Only process valid vertices with content
            if valid_search_node(vertex_data) do
              # Check if content contains search term
              if String.contains?(String.downcase(vertex_data.content), search_term) do
                # Add to results with sorting information
                exact_match =
                  if String.downcase(vertex_data.content) == search_term, do: 0, else: 1

                [{exact_match, vertex_data.id, vertex_data} | acc]
              else
                acc
              end
            else
              acc
            end
          end)
        rescue
          # Return empty list on error
          _ -> []
        end

      # Sort by relevance and extract just the vertex data
      results
      |> Enum.sort()
      |> Enum.map(fn {_, _, vertex} -> vertex end)
      |> Enum.take(10)
    end
  end

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
        Siblings.sort_siblings(node, graph)
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

  defp list_streams(graph) do
    try do
      streams =
        :digraph.vertices(graph)
        |> Enum.reduce([], fn vid, acc ->
          case :digraph.vertex(graph, vid) do
            {^vid, v} ->
              if is_map(v) and Map.get(v, :compound) == true do
                [%{id: v.id} | acc]
              else
                acc
              end

            _ ->
              acc
          end
        end)
        |> Enum.reverse()

      streams
    rescue
      _ -> []
    end
  end

  defp ensure_main_group(graph_id, graph) do
    try do
      # If a Main compound group exists, do nothing
      case :digraph.vertex(graph, "Main") do
        {"Main", _v} ->
          graph

        false ->
          # Collect all top-level nodes (non-compound and no parent)
          child_ids =
            :digraph.vertices(graph)
            |> Enum.filter(fn vid ->
              case :digraph.vertex(graph, vid) do
                {^vid, v} when is_map(v) ->
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

  def update_graph(socket, {graph, node}, operation) do
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

    {nav_up, nav_down, nav_left, nav_right} = compute_nav_flags(graph, node)

    new_socket =
      assign(socket,
        graph: graph,
        f_graph: format_graph(graph),
        form: to_form(changeset, id: new_node.id),
        node: node,
        show_combine: show_combine,
        graph_operation: operation,
        open_read_modal: false,
        nav_can_up: nav_up,
        nav_can_down: nav_down,
        nav_can_left: nav_left,
        nav_can_right: nav_right,
        work_streams: list_streams(graph)
      )
      |> then(fn s ->
        # Close the start stream modal if applicable
        if operation == "start_stream" do
          assign(s, show_start_stream_modal: false)
        else
          s
        end
      end)
      |> then(fn s ->
        # Center on the new node when a stream starts
        if operation == "start_stream" and node and Map.get(node, :id) do
          push_event(s, "center_node", %{id: node.id})
        else
          s
        end
      end)

    {:noreply, new_socket}
  end
end
