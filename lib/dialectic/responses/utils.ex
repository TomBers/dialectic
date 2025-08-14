defmodule Dialectic.Responses.Utils do
  require Logger
  alias Dialectic.Performance.Logger, as: PerfLogger

  def process_chunk(graph, node, data, _module, live_view_topic) do
    # Reduced per-chunk logging to minimize latency
    # Logger.debug(fn -> "Processing chunk for graph #{inspect(graph)} and node #{inspect(node)}" end)
    process_start = DateTime.utc_now()
    PerfLogger.log("Process chunk start")

    update_start = DateTime.utc_now()
    updated_vertex = GraphManager.update_vertex(graph, node, data)
    update_end = DateTime.utc_now()
    update_time_ms = DateTime.diff(update_end, update_start, :millisecond)
    PerfLogger.log("GraphManager.update_vertex completed (took #{update_time_ms}ms)")

    broadcast_start = DateTime.utc_now()
    IO.inspect("Broadcast process chunk: #{DateTime.utc_now()}")
    PerfLogger.log("Broadcast process chunk start")

    Phoenix.PubSub.broadcast(
      Dialectic.PubSub,
      live_view_topic,
      {:stream_chunk, updated_vertex, :node_id, node}
    )

    broadcast_end = DateTime.utc_now()
    broadcast_time_ms = DateTime.diff(broadcast_end, broadcast_start, :millisecond)
    total_time_ms = DateTime.diff(broadcast_end, process_start, :millisecond)

    PerfLogger.log(
      "Broadcast completed (broadcast took #{broadcast_time_ms}ms, total processing took #{total_time_ms}ms)"
    )

    updated_vertex
  end

  def parse_chunk(chunk) do
    parse_start = DateTime.utc_now()
    PerfLogger.log("Parse chunk start")

    try do
      # Optimized parsing with fewer operations
      # Directly split, filter, and decode in one pass with pattern matching
      chunks =
        chunk
        |> String.split("data: ", trim: true)
        |> Enum.flat_map(fn data ->
          case String.trim(data) do
            "" ->
              []

            "[DONE]" ->
              []

            valid_data ->
              decode_start = System.monotonic_time(:microsecond)

              result =
                case Jason.decode(valid_data) do
                  {:ok, decoded} -> [decoded]
                  _ -> []
                end

              decode_end = System.monotonic_time(:microsecond)
              decode_time_us = decode_end - decode_start

              if decode_time_us > 1000 do
                PerfLogger.log("JSON decoding took #{decode_time_us}μs")
              end

              result
          end
        end)

      parse_end = DateTime.utc_now()
      parse_time_ms = DateTime.diff(parse_end, parse_start, :millisecond)

      PerfLogger.log(
        "Parse chunk completed (took #{parse_time_ms}ms, found #{length(chunks)} chunks)"
      )

      {:ok, chunks}
    rescue
      e ->
        error_time = DateTime.utc_now()
        parse_time_ms = DateTime.diff(error_time, parse_start, :millisecond)
        PerfLogger.log("Parse chunk error (after #{parse_time_ms}ms)")
        Logger.error("Error parsing chunk: #{inspect(e)}")
        {:error, "Failed to parse chunk"}
    end
  end

  # The individual decode functions have been removed as they are no longer needed.
  # All parsing is now handled inline in the parse_chunk function above.
end
