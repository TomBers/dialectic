defmodule DialecticWeb.GraphLive do
  use DialecticWeb, :live_view

  alias Dialectic.Graph.{Vertex, GraphActions}
  alias DialecticWeb.{CombineComp, NodeComp}
  alias Dialectic.DbActions.DbWorker

  alias Phoenix.PubSub

  on_mount {DialecticWeb.UserAuth, :mount_current_user}

  def mount(%{"graph_name" => graph_id_uri} = params, _session, socket) do
    graph_id = URI.decode(graph_id_uri)

    live_view_topic = "graph_update:#{socket.id}"
    graph_topic = "graph_update:#{graph_id}"

    user =
      case socket.assigns.current_user do
        nil -> "Anon"
        _ -> socket.assigns.current_user.email
      end

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

    {graph_struct, graph} = GraphManager.get_graph(graph_id)

    {_, node} = :digraph.vertex(graph, node_id)
    changeset = GraphActions.create_new_node(user) |> Vertex.changeset()

    # TODO - can edit is going to be expaned to be more complex, but for the time being, just is not protected
    can_edit = graph_struct.is_public

    {:ok,
     assign(socket,
       live_view_topic: live_view_topic,
       graph_topic: graph_topic,
       graph_struct: graph_struct,
       graph_id: graph_id,
       graph: graph,
       f_graph: format_graph(graph),
       node: Vertex.add_relatives(node, graph),
       form: to_form(changeset),
       show_combine: false,
       user: user,
       can_edit: can_edit,
       node_menu_visible: true,
       drawer_open: true,
       candidate_ids: [],
       group_changeset: to_form(%{"title" => ""}),
       show_group_modal: false,
       graph_operation: "",
       ask_question: true,
       search_term: "",
       search_results: []
     )}
  end

  def handle_event("nodes_box_selected", %{"ids" => ids}, socket) do
    # IO.inspect(ids, label: "Selected Node IDs")

    {:noreply,
     socket
     |> assign(:candidate_ids, ids)
     |> assign(:show_group_modal, true)
     # JS.exec() helpers work too
     |> push_event("open_group_modal", %{ids: ids})}
  end

  def handle_event("cancel_group", _, socket) do
    {:noreply,
     socket
     |> assign(:show_group_modal, false)
     |> assign(:candidate_ids, [])}
  end

  def handle_event("group_nodes", %{"title" => t, "ids" => ids}, socket) do
    graph = GraphManager.create_group(socket.assigns.graph_id, t, String.split(ids, ","))
    DbWorker.save_graph(socket.assigns.graph_id)

    {:noreply,
     socket
     |> assign(
       candidate_ids: [],
       graph: graph,
       f_graph: format_graph(graph),
       show_group_modal: false,
       graph_operation: "create_group"
     )}
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

  def handle_event("branch_list", %{"items" => items}, socket) do
    if !socket.assigns.can_edit do
      {:noreply, socket |> put_flash(:error, "This graph is locked")}
    else
      items
      |> Enum.reduce([], fn item, _acc ->
        {_graph, node} = GraphActions.comment(graph_action_params(socket), item, "Explain: ")
        GraphActions.answer(graph_action_params(socket, node))
      end)

      {:noreply, socket}
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

    # Push event to center the node if coming from search
    if from_search do
      {:noreply, push_event(updated_socket, "center_node", %{id: id})}
    else
      {:noreply, updated_socket}
    end
  end

  def handle_event("answer", %{"vertex" => %{"content" => ""}}, socket), do: {:noreply, socket}

  def handle_event("answer", %{"vertex" => %{"content" => answer}}, socket) do
    if socket.assigns.can_edit do
      update_graph(socket, GraphActions.comment(graph_action_params(socket), answer), "comment")
    else
      {:noreply, socket |> put_flash(:error, "This graph is locked")}
    end
  end

  def handle_event("reply-and-answer", %{"vertex" => %{"content" => answer}} = params, socket) do
    if !socket.assigns.can_edit do
      {:noreply, socket |> put_flash(:error, "This graph is locked")}
    else
      prefix = params["prefix"] || ""
      #  Add a Reply Node and an Answer node
      {_graph, node} = GraphActions.comment(graph_action_params(socket), answer, prefix)

      update_graph(
        socket,
        GraphActions.answer(graph_action_params(socket, node)),
        "answer"
      )
    end
  end

  def handle_event("modal_closed", _, socket) do
    {:noreply, assign(socket, show_combine: false)}
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
         graph_operation: "other_user_change"
       )}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:stream_chunk, updated_vertex, :node_id, node_id}, socket) do
    # This is the streamed LLM response into a node

    if node_id == Map.get(socket.assigns.node, :id) do
      {:noreply, assign(socket, node: updated_vertex)}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:llm_request_complete, node_id}, socket) do
    # Make sure that the graph is saved to the database
    # We pass false so that it does not respect the queue exlusion period and stores the response immediately.
    DbWorker.save_graph(socket.assigns.graph_id, false)

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
    # This is an error message from the LLM API
    # Format the error message to make it clear to the user
    formatted_error =
      cond do
        is_binary(error) ->
          "\n\n⚠️ Error: #{error}"

        is_map(error) && Map.has_key?(error, "error") ->
          "\n\n⚠️ Error: #{inspect(error["error"])}"

        true ->
          "\n\n⚠️ Error: #{inspect(error)}"
      end

    # Update the vertex with the error message
    updated_vertex = GraphManager.update_vertex(socket.assigns.graph_id, node_id, formatted_error)

    # Also put a flash message to ensure the user sees it
    socket =
      put_flash(
        socket,
        :error,
        "LLM request failed. Please check verification status of your API keys."
      )

    # Notify UI that the request is complete (even though it failed)
    Phoenix.PubSub.broadcast(
      Dialectic.PubSub,
      socket.assigns.live_view_topic,
      {:llm_request_complete, node_id}
    )

    if node_id == Map.get(socket.assigns.node, :id) do
      {:noreply, assign(socket, node: updated_vertex)}
    else
      {:noreply, socket}
    end
  end

  defp is_connected_to_graph?(%{metas: metas}, graph_id) do
    Enum.any?(metas, fn %{graph_id: gid} -> gid == graph_id end)
  end

  def format_graph(graph) do
    graph |> Vertex.to_cytoscape_format() |> Jason.encode!()
  end

  # Search for nodes in the graph based on a search term
  defp search_graph_nodes(graph, search_term) do
    search_term = String.downcase(search_term)

    # Process vertices in a more defensive way
    results =
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
            exact_match = if String.downcase(vertex_data.content) == search_term, do: 0, else: 1
            [{exact_match, vertex_data.id, vertex_data} | acc]
          else
            acc
          end
        else
          acc
        end
      end)

    # Sort by relevance and extract just the vertex data
    results
    |> Enum.sort()
    |> Enum.map(fn {_, _, vertex} -> vertex end)
    |> Enum.take(10)
  end

  defp valid_search_node(vertex_data) do
    # not Map.get(vertex_data, :parent_id, false) and
    vertex_data != nil and is_map(vertex_data) and
      Map.has_key?(vertex_data, :content) and is_binary(vertex_data.content) and
      Map.has_key?(vertex_data, :id) and
      not Map.get(vertex_data, :deleted, false)
  end

  defp graph_action_params(socket, node \\ nil) do
    {socket.assigns.graph_id, node || socket.assigns.node, socket.assigns.user,
     socket.assigns.live_view_topic}
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

    {:noreply,
     assign(socket,
       graph: graph,
       f_graph: format_graph(graph),
       form: to_form(changeset, id: new_node.id),
       node: node,
       show_combine: show_combine,
       graph_operation: operation
     )}
  end
end
