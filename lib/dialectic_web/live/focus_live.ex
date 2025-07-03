defmodule DialecticWeb.FocusLive do
  use DialecticWeb, :live_view
  alias Dialectic.Graph.GraphActions
  alias Dialectic.DbActions.DbWorker
  alias DialecticWeb.ConvComp
  alias Dialectic.DbActions.Graphs
  alias Phoenix.PubSub

  import Ecto.Changeset, only: [traverse_errors: 2]
  require Logger

  on_mount {DialecticWeb.UserAuth, :mount_current_user}

  def mount(%{"graph_name" => graph_id_uri, "node_id" => node_id_uri}, _session, socket) do
    graph_id = URI.decode(graph_id_uri)
    node_id = URI.decode(node_id_uri)
    live_view_topic = "graph_update:#{socket.id}"
    graph_topic = "graph_update:#{graph_id}"

    user =
      case socket.assigns.current_user do
        nil -> "Anon"
        _ -> socket.assigns.current_user.email
      end

    {graph_struct, graph} = GraphManager.get_graph(graph_id)

    if !graph_struct.is_public do
      {:ok, socket |> put_flash(:error, "Graph is private") |> redirect(to: ~p"/#{graph_id}")}
    else
      {node, sending_message} =
        if connected?(socket) && :digraph.no_vertices(graph) == 1 do
          {_, first_node} = :digraph.vertex(graph, "1")
          {_, node} = GraphActions.answer({graph_id, first_node, user, live_view_topic})
          {node, true}
        else
          {_, node} =
            GraphManager.find_node_by_id(graph_id, node_id)

          {node, false}
        end

      path =
        GraphManager.path_to_node(graph_id, node)
        |> Enum.reverse()

      # Subscribe to graph updates
      if connected?(socket), do: Phoenix.PubSub.subscribe(Dialectic.PubSub, live_view_topic)

      form = to_form(%{"message" => ""}, as: :message)

      {:ok,
       assign(socket,
         live_view_topic: live_view_topic,
         graph_topic: graph_topic,
         graph: graph,
         graph_struct: graph_struct,
         path: path,
         graph_id: graph_id,
         current_node: node,
         user: user,
         form: form,
         sending_message: sending_message,
         message_text: ""
       )}
    end
  end

  def mount(_params, _session, socket) do
    user =
      case socket.assigns.current_user do
        nil -> "Anon"
        _ -> socket.assigns.current_user.email
      end

    form = to_form(%{"message" => ""}, as: :message)

    {:ok,
     assign(socket,
       live_view_topic: nil,
       graph_topic: nil,
       graph: nil,
       graph_struct: nil,
       path: [],
       graph_id: nil,
       current_node: %{id: ""},
       user: user,
       form: form,
       sending_message: false,
       message_text: ""
     )}
  end

  def handle_event("form_change", %{"message" => %{"message" => message}}, socket) do
    form = to_form(%{"message" => message}, as: :message)
    {:noreply, assign(socket, form: form, message_text: message)}
  end

  # Handles the submission of a message form.
  #
  # This dual-purpose handler:
  # 1. Updates an existing conversation when a graph_id exists
  # 2. Creates a new graph when no graph exists yet
  #
  # Validates that the message is not empty and sanitizes the input for use as a graph title.
  def handle_event("send_message", %{"message" => %{"message" => message}}, socket)
      when message != "" do
    # Sanitize the message to ensure it's suitable as a graph title
    sanitized_message = sanitize_graph_title(message)

    if socket.assigns.graph_id do
      process_user_message(socket, sanitized_message)
    else
      Logger.info("Creating new graph with title: #{sanitized_message}")

      case Graphs.create_new_graph(sanitized_message, socket.assigns.current_user) do
        {:ok, graph} ->
          Logger.info("Successfully created graph: #{graph.title}")

          {:noreply,
           socket
           # |> put_flash(:info, "New exploration started!")
           |> redirect(to: ~p"/#{sanitized_message}/focus/1")}

        {:error, changeset} ->
          Logger.error("Failed to create graph: #{inspect(changeset.errors)}")

          {:noreply,
           socket
           |> put_flash(:error, "Error creating graph: #{format_error(changeset)}")
           |> redirect(to: ~p"/start/new/idea")}

        _ ->
          Logger.error("Unexpected error when creating graph")

          {:noreply,
           socket
           |> put_flash(:error, "Error creating graph")
           |> redirect(to: ~p"/start/new/idea")}
      end
    end
  end

  # Prevent empty messages
  def handle_event("send_message", _params, socket) do
    {:noreply,
     socket
     |> put_flash(:error, "Message cannot be empty")}
  end

  def handle_event("reply-and-answer", %{"vertex" => %{"content" => answer}} = params, socket) do
    prefix = params["prefix"] || ""
    process_user_message(socket, answer, prefix)
  end

  # Processes a user message by creating a message node and triggering an AI response.
  #
  # This function:
  # 1. Adds the user's message as a node in the graph
  # 2. Triggers an AI response to that message
  # 3. Updates the UI state to reflect the ongoing conversation
  #
  # Args:
  #   socket: The current socket
  #   message: The user's message content
  #   prefix: Optional prefix to add to the message (default: "")
  #
  # Returns:
  #   {:noreply, updated_socket}
  def process_user_message(socket, message, prefix \\ "") do
    graph_id = socket.assigns.graph_id
    current_node = socket.assigns.current_node
    user = socket.assigns.user
    live_view_topic = socket.assigns.live_view_topic

    Logger.debug("Processing user message in graph #{graph_id}")

    # Create user message node
    {_graph, user_node} =
      GraphActions.comment({graph_id, current_node, user, live_view_topic}, message, prefix)

    # Trigger AI response
    {_graph, node} = GraphActions.answer({graph_id, user_node, user, live_view_topic})

    # Clear the form and set sending state
    form = to_form(%{"message" => ""}, as: :message)

    # Update current_node to the user_node for proper threading
    path =
      GraphManager.path_to_node(graph_id, node)
      |> Enum.reverse()

    Logger.debug("User message processed, waiting for AI response")

    {:noreply,
     assign(socket,
       form: form,
       sending_message: true,
       current_node: node,
       path: path,
       message_text: ""
     )}
  end

  def handle_info({:stream_chunk, updated_vertex, :node_id, _node_id}, socket) do
    # Refresh the conversation path when nodes are updated
    graph_id = socket.assigns.graph_id
    # current_node = socket.assigns.current_node

    # Get updated path from the root conversation node
    path =
      GraphManager.path_to_node(graph_id, updated_vertex)
      |> Enum.reverse()

    {:noreply,
     assign(socket,
       path: path,
       sending_message: false,
       current_node: updated_vertex
     )}
  end

  def handle_info({:llm_request_complete, _node_id}, socket) do
    # Make sure that the graph is saved to the database
    # We pass false so that it does not respect the queue exlusion period and stores the response immediately.
    DbWorker.save_graph(socket.assigns.graph_id, false)

    # Broadcast new node to all connected users
    PubSub.broadcast(
      Dialectic.PubSub,
      socket.assigns.graph_topic,
      {:other_user_change, self()}
    )

    {:noreply, socket}
  end

  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  # Private helper functions

  # Sanitizes a string to be used as a graph title.
  #
  # Removes any characters that would cause issues when used in URLs or as graph identifiers.
  def sanitize_graph_title(title) do
    title
    |> String.trim()
    # Only allow letters, numbers, spaces, dashes and apostrophes
    |> String.replace(~r/[^a-zA-Z0-9\s'-]/, "")
    # Replace multiple spaces with single space
    |> String.replace(~r/\s+/, " ")
  end

  # Formats changeset errors into a human-readable string.
  defp format_error(changeset) do
    traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.map(fn {k, v} -> "#{k}: #{Enum.join(v, ", ")}" end)
    |> Enum.join("; ")
  end

  # defp get_current_user(socket) do
  #   case socket.assigns[:current_user] do
  #     nil -> "anonymous"
  #     user -> user.email || user.id || "user"
  #   end
  # end
end
