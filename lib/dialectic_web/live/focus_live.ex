defmodule DialecticWeb.FocusLive do
  use DialecticWeb, :live_view
  alias Dialectic.Graph.GraphActions
  alias Dialectic.DbActions.DbWorker
  alias DialecticWeb.ConvComp

  on_mount {DialecticWeb.UserAuth, :mount_current_user}

  def mount(%{"graph_name" => graph_id_uri}, _session, socket) do
    graph_id = URI.decode(graph_id_uri)

    # Ensure graph is started
    {graph_struct, graph} = GraphManager.get_graph(graph_id)

    leaf_nodes = GraphManager.find_leaf_nodes(graph_id)

    {_, node} =
      GraphManager.find_node_by_id(graph_id, List.first(leaf_nodes) |> Map.get(:id))

    path =
      GraphManager.path_to_node(graph_id, node)
      |> Enum.reverse()

    # Subscribe to graph updates
    Phoenix.PubSub.subscribe(Dialectic.PubSub, graph_id)

    form = to_form(%{"message" => ""}, as: :message)

    user =
      case socket.assigns.current_user do
        nil -> "Anon"
        _ -> socket.assigns.current_user.email
      end

    {:ok,
     assign(socket,
       graph: graph,
       graph_struct: graph_struct,
       path: path,
       graph_id: graph_id,
       current_node: node,
       user: user,
       form: form,
       sending_message: false,
       leaf_nodes: leaf_nodes
     )}
  end

  def handle_event("send_message", %{"message" => %{"message" => message}}, socket)
      when message != "" do
    graph_id = socket.assigns.graph_id
    current_node = socket.assigns.current_node
    user = socket.assigns.user

    # Create user message node
    {_graph, user_node} = GraphActions.comment({graph_id, current_node, user}, message)

    {_graph, node} = GraphActions.answer({graph_id, user_node, user})

    # Clear the form and set sending state
    form = to_form(%{"message" => ""}, as: :message)

    # Update current_node to the user_node for proper threading
    path =
      GraphManager.path_to_node(graph_id, node)
      |> Enum.reverse()

    {:noreply,
     assign(socket,
       form: form,
       sending_message: true,
       current_node: node,
       path: path,
       message_text: ""
     )}
  end

  def handle_event("form_change", %{"message" => %{"message" => message}}, socket) do
    form = to_form(%{"message" => message}, as: :message)
    {:noreply, assign(socket, form: form, message_text: message)}
  end

  def handle_event("change-path", %{"leaf" => leaf_id}, socket) do
    graph_id = socket.assigns.graph_id
    {_, node} = GraphManager.find_node_by_id(graph_id, leaf_id)

    path =
      GraphManager.path_to_node(graph_id, node)
      |> Enum.reverse()

    {:noreply,
     assign(socket,
       path: path,
       sending_message: false,
       current_node: node
     )}
  end

  def handle_info({:stream_chunk, updated_vertex, :node_id, _node_id}, socket) do
    # Refresh the conversation path when nodes are updated
    graph_id = socket.assigns.graph_id
    current_node = socket.assigns.current_node

    # Get updated path from the root conversation node
    path =
      GraphManager.path_to_node(graph_id, current_node)
      |> Enum.reverse()

    # If this is the AI response we just generated, update current_node to it
    updated_current_node =
      if updated_vertex.class == "answer" do
        updated_vertex
      else
        current_node
      end

    {:noreply,
     assign(socket,
       path: path,
       sending_message: false,
       current_node: updated_current_node
     )}
  end

  def handle_info({:llm_request_complete, _node_id}, socket) do
    # Make sure that the graph is saved to the database
    # We pass false so that it does not respect the queue exlusion period and stores the response immediately.
    DbWorker.save_graph(socket.assigns.graph_id, false)

    leaf_nodes = GraphManager.find_leaf_nodes(socket.assigns.graph_id)
    {:noreply, assign(socket, leaf_nodes: leaf_nodes)}
  end

  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  # defp get_current_user(socket) do
  #   case socket.assigns[:current_user] do
  #     nil -> "anonymous"
  #     user -> user.email || user.id || "user"
  #   end
  # end
end
