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
      cond do
        is_binary(data) -> data
        is_list(data) -> IO.iodata_to_binary(data)
        true -> to_string(data)
      end

    if text == "" do
      :ok
    else
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
        Phoenix.PubSub.broadcast(
          Dialectic.PubSub,
          live_view_topic,
          {:stream_update, %{id: node, content: Map.get(updated_vertex, :content, "")}}
        )
      end

      :ok
    end
  end
end
