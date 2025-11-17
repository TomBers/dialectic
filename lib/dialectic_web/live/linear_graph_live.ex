defmodule DialecticWeb.LinearGraphLive do
  use DialecticWeb, :live_view

  def mount(%{"graph_name" => graph_id_uri}, _session, socket) do
    graph_id = URI.decode(graph_id_uri)
    graph_struct = Dialectic.DbActions.Graphs.get_graph_by_title(graph_id)
    graph = Dialectic.Graph.Serialise.json_to_graph(graph_struct.data)

    conv =
      Dialectic.Linear.ThreadedConv.prepare_conversation(graph)
      |> Enum.reject(&(Map.get(&1, :compound, false) == true))

    {:ok, assign(socket, conv: conv, graph_id: graph_id, hidden: [])}
  end

  def handle_event("toggle_node", %{"node-id" => node_id}, socket) do
    hidden =
      if Enum.member?(socket.assigns.hidden, node_id),
        do: Enum.reject(socket.assigns.hidden, fn id -> id == node_id end),
        else: [node_id | socket.assigns.hidden]

    {:noreply, socket |> assign(hidden: hidden)}
  end

  def handle_event("toggle_all", _, socket) do
    hidden =
      if length(socket.assigns.hidden) != 0,
        do: [],
        else: Enum.map(socket.assigns.conv, & &1.id)

    {:noreply, socket |> assign(hidden: hidden)}
  end

  def handle_event("prepare_for_print", _params, socket) do
    # Temporarily expand all nodes
    {:noreply, assign(socket, hidden: [])}
  end

  defp message_border_class(class) do
    case class do
      # "user" -> "border-red-400"
      "answer" -> "border-blue-400"
      "thesis" -> "border-green-400"
      "antithesis" -> "border-red-400"
      "synthesis" -> "border-purple-600"
      "deepdive" -> "border-cyan-500"
      _ -> "border-gray-200"
    end
  end
end
