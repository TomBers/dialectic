defmodule Dialectic.Responses.Utils do
  @moduledoc """
  Minimal utilities for streaming updates.

  This module intentionally does not implement any request parsing.
  Upstream callers should pass plaintext tokens/chunks to `set_node_content/4`,
  which sets the content on the node and broadcasts to LiveView subscribers.
  """

  require Logger

  def set_node_content(graph, node, data, live_view_topic) do
    text =
      cond do
        is_binary(data) -> data
        is_list(data) -> IO.iodata_to_binary(data)
        true -> to_string(data)
      end

    if text == "" do
      :ok
    else
      updated_vertex = GraphManager.set_node_content(graph, node, text)
      broadcast_node(updated_vertex, node, live_view_topic)
      :ok
    end
  end

  def set_node_response(graph, node, content, grounding_metadata, live_view_topic) do
    updated_vertex =
      GraphManager.update_vertex_fields(graph, node, %{
        content: content,
        grounding_metadata: grounding_metadata
      })

    broadcast_node(updated_vertex, node, live_view_topic)
    :ok
  end

  defp broadcast_node(nil, _node, _live_view_topic), do: :ok

  defp broadcast_node(updated_vertex, node, live_view_topic) do
    Phoenix.PubSub.broadcast(
      Dialectic.PubSub,
      live_view_topic,
      {:stream_chunk_broadcast, updated_vertex, :node_id, node, nil}
    )
  end
end
