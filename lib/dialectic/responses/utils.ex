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

    updated_vertex = GraphManager.set_node_content(graph, node, text)

    if updated_vertex do
      Phoenix.PubSub.broadcast(
        Dialectic.PubSub,
        live_view_topic,
        {:stream_chunk, updated_vertex, :node_id, node}
      )
    end

    :ok
  end
end
