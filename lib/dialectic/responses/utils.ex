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
              case Jason.decode(valid_data) do
                {:ok, decoded} -> [decoded]
                _ -> []
              end
          end
        end)

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
