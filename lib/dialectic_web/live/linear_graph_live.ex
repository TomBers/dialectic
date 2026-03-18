defmodule DialecticWeb.LinearGraphLive do
  use DialecticWeb, :live_view

  alias Dialectic.Graph.{Vertex, GraphActions}
  alias DialecticWeb.ColUtils
  alias DialecticWeb.Utils.{NodeTitleHelper, UserUtils}
  alias Dialectic.Highlights

  alias Phoenix.PubSub

  require Logger

  on_mount {DialecticWeb.UserAuth, :mount_current_user}

  def mount(%{"graph_name" => graph_id_uri} = params, _session, socket) do
    graph_id = URI.decode(graph_id_uri)

    # Try slug first, then title for backward compatibility
    case Dialectic.DbActions.Graphs.get_graph_by_slug_or_title(graph_id) do
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
            mount_graph(socket, graph_db, params, token_param)
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

  defp mount_graph(socket, graph_db, params, token_param) do
    # Ensure graph is loaded and available (use title for internal GraphManager)
    {_graph_struct, graph} = GraphManager.get_graph(graph_db.title)

    user = UserUtils.current_identity(socket.assigns)

    # Ensure prompt mode is set
    _ =
      Dialectic.Responses.ModeServer.set_mode(
        graph_db.title,
        graph_db.prompt_mode || "university"
      )

    # Generate flat list for HTML minimap
    map_nodes =
      Dialectic.Linear.ThreadedConv.prepare_conversation(graph)
      |> Enum.reject(&(Map.get(&1, :compound, false) == true))
      |> Enum.map(fn node ->
        Map.put(node, :title, NodeTitleHelper.extract_node_title(node))
      end)

    # Determine which node to focus on.
    target_node =
      if params["node_id"] do
        GraphActions.find_node(graph_db.title, params["node_id"])
      else
        GraphManager.find_leaf_nodes(graph_db.title)
        |> Enum.sort_by(
          fn node ->
            case Integer.parse(node.id) do
              {int, _} -> int
              _ -> 0
            end
          end,
          :desc
        )
        |> List.first() || GraphManager.best_node(graph_db.title, nil)
      end

    # Build the linear path from Root -> Target
    linear_path = build_linear_path(graph_db.title, target_node)

    # Determine editability
    can_edit = !graph_db.is_locked

    # Determine the active node for replying (the selected node)
    active_node =
      if target_node do
        GraphActions.find_node(graph_db.title, target_node.id)
      else
        nil
      end

    # Build form for chat input
    new_node = GraphActions.create_new_node(user)
    changeset = Vertex.changeset(new_node)

    # Subscribe to topics when connected
    live_view_topic = "graph_update:#{socket.id}"
    graph_topic = "graph_update:#{graph_db.title}"

    if connected?(socket) do
      PubSub.subscribe(Dialectic.PubSub, live_view_topic)
      PubSub.subscribe(Dialectic.PubSub, graph_topic)
      Highlights.subscribe(graph_db.title)
    end

    # Canonical URL points to the main graph page (linear is an alternate view)
    canonical_url =
      DialecticWeb.Endpoint.url() <> "/g/#{graph_db.slug}"

    prompt_mode =
      Atom.to_string(Dialectic.Responses.ModeServer.get_mode(graph_db.title))

    socket =
      assign(socket,
        linear_path: linear_path,
        map_nodes: map_nodes,
        graph_id: graph_db.title,
        graph_struct: graph_db,
        show_minimap: false,
        show_highlights: true,
        show_highlights_list: false,
        highlights: Highlights.list_highlights(mudg_id: graph_db.title),
        selected_node_id: if(target_node, do: target_node.id, else: nil),
        token: token_param,
        page_title: "#{graph_db.title} — Linear View",
        page_description:
          "Read through \"#{graph_db.title}\" as a linear conversation. Follow the full thread of arguments and ideas on RationalGrid.",
        canonical_url: canonical_url,
        noindex: true,
        # Interactive/editing assigns
        user: user,
        can_edit: can_edit,
        node: active_node,
        form: to_form(changeset),
        ask_question: true,
        streaming_nodes: MapSet.new(),
        titled_nodes: MapSet.new(),
        live_view_topic: live_view_topic,
        graph_topic: graph_topic,
        prompt_mode: prompt_mode,
        show_login_modal: false
      )

    # When a specific node_id was requested via URL params, scroll to it
    socket =
      if connected?(socket) && params["node_id"] && target_node do
        push_event(socket, "scroll_to_node", %{id: target_node.id})
      else
        socket
      end

    {:ok, socket}
  end

  # ── Chat / Form Events ─────────────────────────────────────────────────

  def handle_event("toggle_ask_question", _, socket) do
    {:noreply, assign(socket, ask_question: !socket.assigns.ask_question)}
  end

  def handle_event("answer", %{"vertex" => %{"content" => ""}}, socket), do: {:noreply, socket}

  def handle_event("answer", %{"vertex" => %{"content" => answer}}, socket) do
    if socket.assigns.can_edit do
      result = GraphActions.comment(graph_action_params(socket), answer)
      handle_graph_update(socket, {nil, result}, "comment")
    else
      {:noreply, socket |> put_flash(:error, "This graph is locked")}
    end
  end

  def handle_event(
        "reply-and-answer",
        %{"vertex" => %{"content" => answer}, "prefix" => prefix} = params,
        socket
      ) do
    if not socket.assigns.can_edit do
      {:noreply, socket |> put_flash(:error, "This graph is locked")}
    else
      minimal_context = prefix == "explain"
      highlight_context = Map.get(params, "highlight_context")

      handle_graph_update(
        socket,
        GraphActions.ask_and_answer(
          graph_action_params(socket, socket.assigns.node),
          answer,
          minimal_context: minimal_context,
          highlight_context: highlight_context
        ),
        "answer"
      )
    end
  end

  def handle_event("reply-and-answer", %{"vertex" => %{"content" => answer}} = params, socket) do
    if not socket.assigns.can_edit do
      {:noreply, socket |> put_flash(:error, "This graph is locked")}
    else
      highlight_context = Map.get(params, "highlight_context")

      handle_graph_update(
        socket,
        GraphActions.ask_and_answer(
          graph_action_params(socket, socket.assigns.node),
          answer,
          highlight_context: highlight_context
        ),
        "answer"
      )
    end
  end

  # ── Node Action Events ─────────────────────────────────────────────────

  def handle_event("select_node", %{"id" => node_id}, socket) do
    node = GraphActions.find_node(socket.assigns.graph_id, node_id)

    if node do
      {:noreply,
       socket
       |> assign(node: node, selected_node_id: node.id)
       |> push_event("scroll_to_node", %{id: node.id})}
    else
      {:noreply, socket}
    end
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

      handle_graph_update(
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

  def handle_event("unnote", %{"node" => node_id}, socket) do
    if socket.assigns.current_user == nil do
      {:noreply, assign(socket, show_login_modal: true)}
    else
      Dialectic.DbActions.Notes.remove_note(
        socket.assigns.graph_id,
        node_id,
        socket.assigns.current_user
      )

      handle_graph_update(
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

  def handle_event("node_branch", %{"id" => node_id}, socket) do
    if not socket.assigns.can_edit do
      {:noreply, socket |> put_flash(:error, "This graph is locked")}
    else
      node = GraphActions.find_node(socket.assigns.graph_id, node_id)

      handle_graph_update(
        socket,
        {nil, GraphActions.branch(graph_action_params(socket, node))},
        "branch"
      )
    end
  end

  def handle_event("node_related_ideas", %{"id" => node_id}, socket) do
    if not socket.assigns.can_edit do
      {:noreply, socket |> put_flash(:error, "This graph is locked")}
    else
      node = GraphActions.find_node(socket.assigns.graph_id, node_id)

      handle_graph_update(
        socket,
        {nil, GraphActions.related_ideas(graph_action_params(socket, node))},
        "ideas"
      )
    end
  end

  def handle_event("show_login_required", _, socket) do
    {:noreply, assign(socket, show_login_modal: true)}
  end

  def handle_event("close_login_modal", _, socket) do
    {:noreply, assign(socket, show_login_modal: false)}
  end

  # ── Existing Read-Only Events ──────────────────────────────────────────

  def handle_event(
        "selection_highlight",
        %{
          "selected_text" => selected_text,
          "node_id" => node_id,
          "offsets" => offsets
        },
        socket
      ) do
    {:noreply,
     socket
     |> push_event("create_highlight", %{
       text: selected_text,
       offsets: offsets,
       node_id: node_id
     })}
  end

  def handle_event("toggle_minimap", _, socket) do
    {:noreply, assign(socket, show_minimap: !socket.assigns.show_minimap)}
  end

  def handle_event("close_minimap", _, socket) do
    {:noreply, assign(socket, show_minimap: false)}
  end

  def handle_event("toggle_highlights", _, socket) do
    {:noreply, assign(socket, show_highlights: !socket.assigns.show_highlights)}
  end

  def handle_event("toggle_highlights_list", _, socket) do
    {:noreply, assign(socket, show_highlights_list: !socket.assigns.show_highlights_list)}
  end

  def handle_event("jump_to_highlight", %{"id" => highlight_id, "node_id" => node_id}, socket) do
    socket =
      if Enum.any?(socket.assigns.linear_path, &(&1.id == node_id)) do
        socket
      else
        node = GraphActions.find_node(socket.assigns.graph_id, node_id)

        if node do
          path =
            GraphManager.path_to_node(socket.assigns.graph_id, node)
            |> Enum.reverse()
            |> Enum.map(fn n -> Map.put(n, :title, NodeTitleHelper.extract_node_title(n)) end)

          assign(socket, selected_node_id: node.id, linear_path: path)
        else
          socket
        end
      end

    {:noreply, push_event(socket, "scroll_to_highlight", %{id: highlight_id})}
  end

  def handle_event("navigate_to_node", %{"node_id" => node_id} = _params, socket) do
    node = GraphActions.find_node(socket.assigns.graph_id, node_id)

    if node do
      path =
        GraphManager.path_to_node(socket.assigns.graph_id, node)
        |> Enum.reverse()
        |> Enum.map(fn n -> Map.put(n, :title, NodeTitleHelper.extract_node_title(n)) end)

      {:noreply,
       socket
       |> assign(selected_node_id: node.id, linear_path: path, node: node)
       |> push_event("scroll_to_node", %{id: node.id})}
    else
      {:noreply, socket |> put_flash(:error, "Node not found")}
    end
  end

  def handle_event("node_clicked", %{"id" => id}, socket) do
    node = GraphActions.find_node(socket.assigns.graph_id, id)

    if node do
      path =
        GraphManager.path_to_node(socket.assigns.graph_id, node)
        |> Enum.reverse()
        |> Enum.map(fn n -> Map.put(n, :title, NodeTitleHelper.extract_node_title(n)) end)

      {:noreply,
       socket
       |> assign(selected_node_id: node.id, linear_path: path, node: node)
       |> push_event("scroll_to_node", %{id: node.id})}
    else
      {:noreply, socket}
    end
  end

  def handle_event("update_exploration_progress", _params, socket) do
    {:noreply, socket}
  end

  # ── Selection Actions (from SelectionActionsComp) ──────────────────────

  def handle_info({:selection_action, params}, socket) do
    %{
      action: action,
      selected_text: selected_text,
      node_id: node_id,
      offsets: offsets,
      highlight: existing_highlight
    } = params

    extra = Map.drop(params, [:action, :selected_text, :node_id, :offsets, :highlight])

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

  # ── Streaming / PubSub Handlers ────────────────────────────────────────

  def handle_info({:stream_chunk, updated_vertex, :node_id, node_id}, socket) do
    # Re-broadcast to all users on the graph
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
    if self() == sender_pid do
      {:noreply, socket}
    else
      {:noreply, update_streaming_node(socket, updated_vertex, node_id)}
    end
  end

  def handle_info({:llm_request_complete, node_id}, socket) do
    Logger.debug(fn ->
      "[LinearGraphLive] llm_request_complete node_id=#{inspect(node_id)}"
    end)

    # Refresh the map_nodes and linear_path to include the new node
    socket = refresh_graph_data(socket, node_id)

    socket =
      socket
      |> assign(streaming_nodes: MapSet.delete(socket.assigns.streaming_nodes, node_id))

    {:noreply, socket}
  end

  def handle_info({:stream_error, error, :node_id, node_id}, socket) do
    Logger.debug(fn ->
      "[LinearGraphLive] stream_error node_id=#{inspect(node_id)} error=#{inspect(error)}"
    end)

    updated_vertex = GraphManager.update_vertex(socket.assigns.graph_id, node_id, error)

    socket =
      if socket.assigns.node && node_id == Map.get(socket.assigns.node, :id) do
        assign(socket, node: updated_vertex)
      else
        socket
      end

    {:noreply, socket}
  end

  def handle_info({:other_user_change, sender_pid}, socket) do
    if self() == sender_pid do
      {:noreply, socket}
    else
      # Another user changed the graph — refresh minimap
      socket = refresh_map_nodes(socket)
      {:noreply, socket}
    end
  end

  # ── Highlight PubSub ───────────────────────────────────────────────────

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

  # Catch-all for any unhandled PubSub messages (e.g. Presence)
  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  # ── Private Helpers ────────────────────────────────────────────────────

  defp graph_action_params(socket, node \\ nil) do
    node_to_use =
      cond do
        node != nil -> node
        is_map(socket.assigns.node) -> socket.assigns.node
        true -> %{id: "1", content: "", children: [], parents: []}
      end

    graph_id = socket.assigns.graph_id

    unless GraphManager.exists?(graph_id) do
      case Dialectic.DbActions.Graphs.get_graph_by_title(graph_id) do
        nil ->
          Logger.warning("Attempted to access non-existent graph: #{graph_id}")

        _graph ->
          DynamicSupervisor.start_child(GraphSupervisor, {GraphManager, graph_id})
      end
    end

    {graph_id, node_to_use, socket.assigns.user, socket.assigns.live_view_topic}
  end

  defp handle_graph_update(socket, {_graph, node}, operation) do
    new_node = GraphActions.create_new_node(socket.assigns.user)
    changeset = Vertex.changeset(new_node)

    # For operations that create new nodes, update the selected node and path
    socket =
      if operation in ["comment", "answer", "branch", "ideas", "note", "unnote"] and node != nil do
        # Refresh the map nodes to include any newly created nodes
        socket = refresh_map_nodes(socket)

        # For note/unnote, just update the node in the linear path without changing selection
        if operation in ["note", "unnote"] do
          # Update the node in the linear_path with the new noted_by data
          updated_path =
            Enum.map(socket.assigns.linear_path, fn n ->
              if n.id == node.id do
                Map.put(node, :title, NodeTitleHelper.extract_node_title(node))
              else
                n
              end
            end)

          assign(socket, linear_path: updated_path, node: node)
        else
          # For structural changes, rebuild the path to show the new node
          new_path = build_linear_path(socket.assigns.graph_id, node)

          socket
          |> assign(
            selected_node_id: node.id,
            node: node,
            linear_path: new_path
          )
          |> push_event("scroll_to_node", %{id: node.id})
        end
      else
        socket
      end

    socket =
      assign(socket,
        form: to_form(changeset, id: new_node.id),
        prompt_mode:
          Atom.to_string(Dialectic.Responses.ModeServer.get_mode(socket.assigns.graph_id))
      )

    # Broadcast structural changes to other users
    if operation in ["comment", "answer", "branch", "ideas"] do
      PubSub.broadcast(
        Dialectic.PubSub,
        socket.assigns.graph_topic,
        {:other_user_change, self()}
      )
    end

    {:noreply, socket}
  end

  defp build_linear_path(graph_id, target_node) do
    if target_node do
      GraphManager.path_to_node(graph_id, target_node)
      |> Enum.reverse()
      |> Enum.map(fn node ->
        Map.put(node, :title, NodeTitleHelper.extract_node_title(node))
      end)
    else
      []
    end
  end

  defp refresh_map_nodes(socket) do
    {_graph_struct, graph} = GraphManager.get_graph(socket.assigns.graph_id)

    map_nodes =
      Dialectic.Linear.ThreadedConv.prepare_conversation(graph)
      |> Enum.reject(&(Map.get(&1, :compound, false) == true))
      |> Enum.map(fn node ->
        Map.put(node, :title, NodeTitleHelper.extract_node_title(node))
      end)

    assign(socket, map_nodes: map_nodes)
  end

  defp refresh_graph_data(socket, target_node_id) do
    socket = refresh_map_nodes(socket)

    # If the completed node is in our current path or is a child of a node in our path,
    # rebuild the linear path to include it
    node = GraphActions.find_node(socket.assigns.graph_id, target_node_id)

    if node do
      new_path = build_linear_path(socket.assigns.graph_id, node)

      socket
      |> assign(
        linear_path: new_path,
        selected_node_id: node.id,
        node: node
      )
      |> push_event("scroll_to_node", %{id: node.id})
    else
      socket
    end
  end

  defp update_streaming_node(socket, updated_vertex, node_id) do
    new_content = Map.get(updated_vertex, :content, "")

    # Track title updates for streaming nodes
    already_titled = MapSet.member?(socket.assigns.titled_nodes, node_id)
    new_title = NodeTitleHelper.extract_node_title(updated_vertex)
    needs_title_set = !already_titled && new_title != ""

    socket =
      if needs_title_set do
        assign(socket, titled_nodes: MapSet.put(socket.assigns.titled_nodes, node_id))
      else
        socket
      end

    # Mark node as streaming
    socket = assign(socket, streaming_nodes: MapSet.put(socket.assigns.streaming_nodes, node_id))

    # Update the node in the linear_path if it's present
    updated_path =
      Enum.map(socket.assigns.linear_path, fn n ->
        if n.id == node_id do
          %{n | content: new_content}
        else
          n
        end
      end)

    socket = assign(socket, linear_path: updated_path)

    # If the user is viewing this node, update the active node too
    if socket.assigns.node && node_id == Map.get(socket.assigns.node, :id) do
      current_content = Map.get(socket.assigns.node, :content, "")

      if current_content == new_content do
        socket
      else
        node = %{socket.assigns.node | content: new_content}
        assign(socket, node: node)
      end
    else
      socket
    end
  end

  # ── Selection Action Handlers ──────────────────────────────────────────
  # These handle text selection actions from SelectionActionsComp

  defp handle_selection_action(
         :highlight_only,
         selected_text,
         node_id,
         offsets,
         existing_highlight,
         _params,
         socket
       ) do
    socket = maybe_create_highlight(socket, node_id, offsets, selected_text, existing_highlight)
    {:noreply, socket}
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
    if not socket.assigns.can_edit do
      {:noreply, socket |> put_flash(:error, "This graph is locked")}
    else
      socket = maybe_create_highlight(socket, node_id, offsets, selected_text, existing_highlight)

      node = GraphActions.find_node(socket.assigns.graph_id, node_id)

      if node do
        handle_graph_update(
          socket,
          GraphActions.ask_and_answer(
            graph_action_params(socket, node),
            "Explain: #{selected_text}",
            minimal_context: true,
            highlight_context: selected_text
          ),
          "answer"
        )
      else
        {:noreply, socket}
      end
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
    if not socket.assigns.can_edit do
      {:noreply, socket |> put_flash(:error, "This graph is locked")}
    else
      socket = maybe_create_highlight(socket, node_id, offsets, selected_text, existing_highlight)

      node = GraphActions.find_node(socket.assigns.graph_id, node_id)

      if node do
        handle_graph_update(
          socket,
          {nil, GraphActions.branch(graph_action_params(socket, node))},
          "branch"
        )
      else
        {:noreply, socket}
      end
    end
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
    if not socket.assigns.can_edit do
      {:noreply, socket |> put_flash(:error, "This graph is locked")}
    else
      socket = maybe_create_highlight(socket, node_id, offsets, selected_text, existing_highlight)

      node = GraphActions.find_node(socket.assigns.graph_id, node_id)

      if node do
        handle_graph_update(
          socket,
          {nil, GraphActions.related_ideas(graph_action_params(socket, node))},
          "ideas"
        )
      else
        {:noreply, socket}
      end
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
    if not socket.assigns.can_edit do
      {:noreply, socket |> put_flash(:error, "This graph is locked")}
    else
      socket = maybe_create_highlight(socket, node_id, offsets, selected_text, existing_highlight)

      node = GraphActions.find_node(socket.assigns.graph_id, node_id)

      if node do
        handle_graph_update(
          socket,
          GraphActions.ask_and_answer(
            graph_action_params(socket, node),
            question_text,
            highlight_context: selected_text
          ),
          "answer"
        )
      else
        {:noreply, socket}
      end
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
    if not socket.assigns.can_edit do
      {:noreply, socket |> put_flash(:error, "This graph is locked")}
    else
      socket = maybe_create_highlight(socket, node_id, offsets, selected_text, existing_highlight)

      node = GraphActions.find_node(socket.assigns.graph_id, node_id)

      if node do
        result = GraphActions.comment(graph_action_params(socket, node), comment_text)
        handle_graph_update(socket, {nil, result}, "comment")
      else
        {:noreply, socket}
      end
    end
  end

  # Catch-all for unhandled selection actions
  defp handle_selection_action(_action, _text, _node_id, _offsets, _highlight, _params, socket) do
    {:noreply, socket}
  end

  defp maybe_create_highlight(socket, node_id, offsets, selected_text, existing_highlight) do
    if existing_highlight do
      socket
    else
      case Highlights.create_highlight(%{
             mudg_id: socket.assigns.graph_id,
             node_id: node_id,
             start_offset: offsets["start"],
             end_offset: offsets["end"],
             selected_text_snapshot: selected_text
           }) do
        {:ok, _highlight} -> socket
        {:error, _} -> socket
      end
    end
  end

  defp message_border_class(class) do
    ColUtils.border_class(class)
  end
end
