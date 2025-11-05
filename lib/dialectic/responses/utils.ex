defmodule Dialectic.Responses.Utils do
  @moduledoc false

  def process_text(graph, node, data, _module, live_view_topic) do
    updated_vertex = GraphManager.update_vertex(graph, node, data)

    Phoenix.PubSub.broadcast(
      Dialectic.PubSub,
      live_view_topic,
      {:llm_text, updated_vertex, :node_id, node}
    )
  end
end
