defmodule Dialectic.Responses.Utils do
  require Logger

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
      # Tolerant SSE parser:
      # - Split by lines
      # - Only consume lines starting with "data:"
      # - Ignore other fields (event:, id:, etc.) and [DONE]
      lines =
        case chunk do
          iodata when is_list(iodata) or is_binary(iodata) -> IO.iodata_to_binary(iodata)
          other -> to_string(other)
        end
        |> String.split(~r/\r?\n/, trim: false)

      chunks =
        lines
        |> Enum.reduce([], fn line, acc ->
          trimmed = String.trim(line)

          if String.starts_with?(trimmed, "data:") do
            payload =
              case trimmed do
                "data:" <> rest -> String.trim_leading(rest)
                _ -> ""
              end

            cond do
              payload == "" or payload == "[DONE]" ->
                acc

              true ->
                case Jason.decode(payload) do
                  {:ok, decoded} -> [decoded | acc]
                  _ -> acc
                end
            end
          else
            acc
          end
        end)
        |> Enum.reverse()

      {:ok, chunks}
    rescue
      e ->
        Logger.error("Error parsing chunk: #{inspect(e)}")
        {:error, "Failed to parse chunk"}
    end
  end

  # The individual decode functions have been removed as they are no longer needed.
  # All parsing is now handled inline in the parse_chunk function above.
end
