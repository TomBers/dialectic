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
          {:stream_chunk, updated_vertex, :node_id, node}
        )
      end

      :ok
    end
  end

  @doc """
  Parse a Server-Sent Events (SSE) chunk into a list of decoded JSON payloads.

  - Ignores non-data fields (event:, id:, retry:)
  - Ignores control payloads like [DONE]
  - Accepts both LF and CRLF newlines
  - Supports:
    * Single JSON across multiple data: lines
    * NDJSON: multiple JSON objects across data: lines in a single frame
  """
  @spec parse_chunk(binary()) :: {:ok, [map()]}
  def parse_chunk(input) when is_binary(input) do
    input
    |> String.replace("\r\n", "\n")
    |> String.split(~r/\n{2,}/, trim: false)
    |> Enum.reduce([], fn frame, acc ->
      lines =
        frame
        |> String.split("\n")
        |> Enum.map(&String.trim_trailing(&1))

      data_lines =
        Enum.reduce(lines, [], fn line, dl ->
          case String.split(line, ":", parts: 2) do
            ["data", rest] ->
              payload = String.trim_leading(rest)
              [payload | dl]

            _ ->
              dl
          end
        end)
        |> Enum.reverse()

      cond do
        data_lines == [] ->
          acc

        Enum.any?(data_lines, &(&1 == "[DONE]")) ->
          acc

        Enum.all?(data_lines, &(&1 == "")) ->
          acc

        true ->
          joined = Enum.join(data_lines, "\n")

          case Jason.decode(joined) do
            {:ok, decoded} ->
              acc ++ [decoded]

            {:error, _} ->
              ndjson_lines =
                joined
                |> String.split("\n")
                |> Enum.map(&String.trim/1)
                |> Enum.reject(&(&1 == ""))

              with true <- ndjson_lines != [],
                   decoded when is_list(decoded) <-
                     Enum.reduce_while(ndjson_lines, [], fn line, dacc ->
                       case Jason.decode(line) do
                         {:ok, d} -> {:cont, [d | dacc]}
                         {:error, _} -> {:halt, :error}
                       end
                     end) do
                acc ++ Enum.reverse(decoded)
              else
                _ ->
                  Logger.warning("SSE parse failed for frame: #{inspect(joined)}")
                  acc
              end
          end
      end
    end)
    |> then(&{:ok, &1})
  end
end
