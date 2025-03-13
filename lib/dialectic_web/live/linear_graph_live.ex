defmodule DialecticWeb.LinearGraphLive do
  use DialecticWeb, :live_view

  def mount(%{"graph_name" => graph_id_uri}, _session, socket) do
    graph_id = URI.decode(graph_id_uri)
    {graph_struct, graph} = GraphManager.get_graph(graph_id)

    conv = Dialectic.Linear.ThreadedConv.prepare_conversation(graph)

    {:ok, assign(socket, conv: conv, graph_struct: graph_struct)}
  end
end
