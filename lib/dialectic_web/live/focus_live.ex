defmodule DialecticWeb.FocusLive do
  use DialecticWeb, :live_view
  alias DialecticWeb.Live.TextUtils
  alias Dialectic.Graph.GraphActions

  on_mount {DialecticWeb.UserAuth, :mount_current_user}

  def mount(%{"graph_name" => graph_id_uri}, _session, socket) do
    graph_id = URI.decode(graph_id_uri)

    # Ensure graph is started
    {graph_struct, graph} = GraphManager.get_graph(graph_id)

    {_, node} = GraphManager.find_node_by_id(graph_id, "2")

    path =
      GraphManager.path_to_node(graph_id, node)
      |> Enum.reverse()

    # Subscribe to graph updates
    Phoenix.PubSub.subscribe(Dialectic.PubSub, graph_id)

    form = to_form(%{"message" => ""}, as: :message)

    {:ok,
     assign(socket,
       graph: graph,
       graph_struct: graph_struct,
       path: path,
       graph_id: graph_id,
       current_node: node,
       form: form,
       sending_message: false,
       message_text: ""
     )}
  end

  def handle_event("send_message", %{"message" => %{"message" => message}}, socket)
      when message != "" do
    graph_id = socket.assigns.graph_id
    current_node = socket.assigns.current_node
    user = get_current_user(socket)

    # Create user message node
    user_node = GraphActions.comment({graph_id, current_node, user}, message)

    # Generate AI response
    if user_node do
      GraphActions.answer({graph_id, user_node, user})
    end

    # Clear the form and set sending state
    form = to_form(%{"message" => ""}, as: :message)

    # Update current_node to the user_node for proper threading
    updated_current_node = user_node || current_node

    {:noreply,
     assign(socket,
       form: form,
       sending_message: true,
       current_node: updated_current_node,
       message_text: ""
     )}
  end

  def handle_event("form_change", %{"message" => %{"message" => message}}, socket) do
    form = to_form(%{"message" => message}, as: :message)
    {:noreply, assign(socket, form: form, message_text: message)}
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

  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  defp get_current_user(socket) do
    case socket.assigns[:current_user] do
      nil -> "anonymous"
      user -> user.email || user.id || "user"
    end
  end

  defp get_message_type(node, index) do
    case node.class do
      "user" -> "user"
      "answer" -> "assistant"
      _ -> if rem(index, 2) == 0, do: "user", else: "assistant"
    end
  end
end
