defmodule Dialectic.Responses.Utils do
  @moduledoc """
  Minimal utilities for streaming updates.

  This module intentionally does not implement any request parsing.
  Upstream callers should pass plaintext tokens/chunks to `process_chunk/5`,
  which appends them to the node and broadcasts to LiveView subscribers.
  """

  require Logger

  @stream_debug_env_key "E2E_STREAM_DEBUG"

  defp stream_debug? do
    case System.get_env(@stream_debug_env_key) do
      "1" -> true
      "true" -> true
      "TRUE" -> true
      _ -> false
    end
  end

  @spec process_chunk(
          graph :: any(),
          node :: any(),
          data :: iodata(),
          module :: module(),
          live_view_topic :: term()
        ) :: :ok
  def process_chunk(graph, node, data, _module, live_view_topic) do
    text =
      cond do
        is_binary(data) -> data
        is_list(data) -> IO.iodata_to_binary(data)
        true -> to_string(data)
      end

    if text == "" do
      if stream_debug?(),
        do: Logger.debug("[stream] empty_chunk graph=#{inspect(graph)} node=#{inspect(node)}")

      :ok
    else
      if stream_debug?() do
        fence_ct = Regex.scan(~r/```/, text) |> length()

        Logger.debug(
          "[stream] chunk_received size=#{byte_size(text)} fences_in_chunk=#{fence_ct} preview=#{inspect(String.slice(text, 0, 80))}"
        )
      end

      updated_vertex =
        try do
          GraphManager.update_vertex(graph, node, text)
        rescue
          exception ->
            Logger.error(
              "process_chunk update_vertex_exception=#{Exception.format(:error, exception, __STACKTRACE__)} graph=#{inspect(graph)} node=#{inspect(node)}"
            )

            nil
        catch
          :exit, _ ->
            nil
        end

      if updated_vertex do
        if stream_debug?() do
          content = updated_vertex.content || ""
          total_len = byte_size(content)
          total_fences = Regex.scan(~r/```/, content) |> length()
          open_fence? = rem(total_fences, 2) == 1

          Logger.debug(
            "[stream] after_update node=#{inspect(node)} len=#{total_len} fences_total=#{total_fences} open_fence?=#{open_fence?}"
          )
        end

        Phoenix.PubSub.broadcast(
          Dialectic.PubSub,
          live_view_topic,
          {:stream_chunk, updated_vertex, :node_id, node}
        )
      end

      :ok
    end
  end
end
