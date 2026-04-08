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

      if updated_vertex do
        # Broadcast :stream_chunk_broadcast directly with nil sender_pid to avoid
        # amplification. When using :stream_chunk, each subscribed LiveView would
        # re-broadcast to the same topic, causing N^2 messages with N clients.
        # Using :stream_chunk_broadcast with nil sender ensures all clients process
        # the update exactly once without re-broadcasting.
        Phoenix.PubSub.broadcast(
          Dialectic.PubSub,
          live_view_topic,
          {:stream_chunk_broadcast, updated_vertex, :node_id, node, nil}
        )
      end

      :ok
    end
  end
end
