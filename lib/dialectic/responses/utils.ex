defmodule Dialectic.Responses.Utils do
  require Logger

  def to_binary(term) do
    case term do
      iodata when is_list(iodata) or is_binary(iodata) -> IO.iodata_to_binary(iodata)
      other -> to_string(other)
    end
  end

  def process_chunk(graph, node, data, _module, live_view_topic) do
    # Logger.info("Processing chunk for graph #{graph} and node #{node}. Data: #{data}")
    updated_vertex = GraphManager.update_vertex(graph, node, data)

    Phoenix.PubSub.broadcast(
      Dialectic.PubSub,
      live_view_topic,
      {:stream_chunk, updated_vertex, :node_id, node}
    )
  end

  def parse_chunk(chunk) do
    try do
      # Robust SSE parsing:
      # - Normalize CRLF to LF
      # - Split by SSE frame delimiter (blank line)
      # - For each frame, concatenate multiple "data:" lines with "\n"
      # - Ignore other fields (event:, id:, retry:, etc.) and [DONE]
      # - Support NDJSON within a payload (decode per-line if whole decode fails)
      bin =
        chunk
        |> to_binary()
        |> String.replace("\r\n", "\n")

      frames = split_sse_frames(bin)

      decoded =
        frames
        |> Enum.flat_map(fn frame ->
          payload = collect_data_payload(frame)

          cond do
            payload == "" ->
              []

            payload == "[DONE]" ->
              []

            true ->
              decode_payload(payload)
          end
        end)

      {:ok, decoded}
    rescue
      e ->
        Logger.error("Error parsing chunk: #{inspect(e)}")
        {:error, "Failed to parse chunk"}
    end
  end

  defp split_sse_frames(bin) do
    # If the caller already provided a single frame, this returns a single entry.
    # If multiple frames are coalesced, split them on the SSE frame delimiter.
    bin
    |> String.split("\n\n", trim: true)
  end

  defp collect_data_payload(frame) do
    frame
    |> String.split("\n", trim: false)
    |> Enum.reduce([], fn line, acc ->
      trimmed = String.trim(line)

      case trimmed do
        "data:" <> rest ->
          # Per SSE spec, a single space after ":" is optional; strip it.
          [String.trim_leading(rest) | acc]

        _ ->
          acc
      end
    end)
    |> Enum.reverse()
    |> Enum.join("\n")
    |> String.trim()
  end

  defp decode_payload(payload) do
    # Try decoding the whole payload first.
    case Jason.decode(payload) do
      {:ok, decoded} ->
        [decoded]

      _ ->
        # Fall back to NDJSON: decode line-by-line, ignoring failures.
        payload
        |> String.split(~r/\r?\n/, trim: true)
        |> Enum.reduce([], fn line, acc ->
          case Jason.decode(line) do
            {:ok, decoded} -> [decoded | acc]
            _ -> acc
          end
        end)
        |> Enum.reverse()
    end
  end

  # The individual decode functions have been removed as they are no longer needed.
  # All parsing is now handled inline in the parse_chunk function above.

  def handle_sse_stream(module, {:data, data}, context, graph, to_node, live_view_topic) do
    incoming = to_binary(data)

    buf = Process.get(:sse_buf) || ""
    combined = buf <> incoming
    frames = String.split(combined, "\n\n", trim: false)

    {full_frames, remainder} =
      if String.ends_with?(combined, "\n\n") do
        {frames, ""}
      else
        {Enum.slice(frames, 0..-2//1), List.last(frames) || ""}
      end

    Enum.each(full_frames, fn frame ->
      case module.parse_chunk(frame) do
        {:ok, chunks} ->
          Enum.each(chunks, fn chunk ->
            module.handle_result(chunk, graph, to_node, live_view_topic)
          end)

        {:error, _} ->
          :ok
      end
    end)

    Process.put(:sse_buf, remainder)
    {:cont, context}
  end

  def handle_sse_stream(module, {:done, _data}, context, graph, to_node, live_view_topic) do
    remainder = Process.get(:sse_buf) || ""

    if String.trim(remainder) != "" do
      case module.parse_chunk(remainder) do
        {:ok, chunks} ->
          Enum.each(chunks, fn chunk ->
            module.handle_result(chunk, graph, to_node, live_view_topic)
          end)

        {:error, _} ->
          :ok
      end
    end

    Process.delete(:sse_buf)
    {:cont, context}
  end
end
