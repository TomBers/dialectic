defmodule DialecticWeb.LinearGraphLive do
  use DialecticWeb, :live_view

  def mount(%{"graph_name" => graph_id_uri}, _session, socket) do
    graph_id = URI.decode(graph_id_uri)
    {_graph_struct, graph} = GraphManager.get_graph(graph_id)

    conv = Dialectic.Linear.ThreadedConv.prepare_conversation(graph)

    {:ok, assign(socket, conv: conv, graph_id: graph_id, hidden: [])}
  end

  def handle_event("toggle_node", %{"node-id" => node_id}, socket) do
    hidden =
      if Enum.any?(socket.assigns.hidden, fn id -> id == node_id end),
        do: Enum.filter(socket.assigns.hidden, fn id -> id != node_id end),
        else: [node_id | socket.assigns.hidden]

    {:noreply, socket |> assign(hidden: hidden)}
  end

  defp full_html(content) do
    Earmark.as_html!(content) |> Phoenix.HTML.raw()
  end

  defp modal_title(nil), do: ""

  defp modal_title(class) do
    String.upcase(class) <> ":"
  end

  defp message_border_class(class) do
    case class do
      # "user" -> "border-red-400"
      "answer" -> "border-blue-400"
      "thesis" -> "border-green-400"
      "antithesis" -> "border-red-400"
      "synthesis" -> "border-purple-600"
      _ -> "border-gray-200"
    end
  end
end
