defmodule Dialectic.Responses.Utils do
  @moduledoc """
  Minimal utilities for streaming updates.

  This module intentionally does not implement any request parsing.
  Upstream callers should pass plaintext tokens/chunks to `process_chunk/5`,
  which appends them to the node and broadcasts to LiveView subscribers.
  """

  require Logger

  @spec process_chunk(
          graph :: any(),
          node :: any(),
          data :: iodata(),
          module :: module(),
          live_view_topic :: term()
        ) :: :ok
  def process_chunk(graph, node, data, _module, live_view_topic) do
    text =
      case data do
        iodata when is_list(iodata) or is_binary(iodata) -> IO.iodata_to_binary(iodata)
        other -> to_string(other)
      end

    updated_vertex = GraphManager.update_vertex(graph, node, text)

    ts_ms = System.system_time(:millisecond)

    Logger.info(
      "llm_timing chunk_broadcast ts_ms=#{ts_ms} bytes=#{byte_size(text)} graph=#{inspect(graph)} node=#{inspect(node)}"
    )

    Phoenix.PubSub.broadcast(
      Dialectic.PubSub,
      live_view_topic,
      {:stream_chunk, updated_vertex, :node_id, node}
    )

    :ok
  end
end
