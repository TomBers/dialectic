defmodule Dialectic.Responses.Utils do
  require Logger

  def process_chunk(graph, node, data, _module, live_view_topic) do
    Logger.info("Processing chunk for graph #{graph} and node #{node}. Data: #{data}")
    updated_vertex = GraphManager.update_vertex(graph, node, data)

    Phoenix.PubSub.broadcast(
      Dialectic.PubSub,
      live_view_topic,
      {:stream_chunk, updated_vertex, :node_id, node}
    )
  end

  def process_error(graph, node, error_message, live_view_topic) do
    Logger.error("Error for graph #{graph} and node #{node}: #{error_message}")
    _updated_vertex = GraphManager.update_vertex(graph, node, "\n\nError: #{error_message}")

    Phoenix.PubSub.broadcast(
      Dialectic.PubSub,
      live_view_topic,
      {:stream_error, "\n\nError: #{error_message}", :node_id, node}
    )
  end

  def parse_chunk(chunk) do
    try do
      # Process each data chunk immediately to avoid buffering
      chunks =
        chunk
        |> String.split("data: ", trim: true)
        |> Enum.map(&String.trim/1)
        |> Enum.map(&decode/1)
        |> Enum.reject(&is_nil/1)

      # Handle empty result case quickly
      if chunks == [] do
        {:ok, []}
      else
        # Check if any chunk contains an error
        error_chunk =
          Enum.find(chunks, fn
            %{"error" => _} -> true
            _ -> false
          end)

        if error_chunk do
          Logger.error("Error in chunk response: #{inspect(error_chunk)}")
          # Still return the chunks so they can be handled by the worker
          {:ok, chunks}
        else
          {:ok, chunks}
        end
      end
    rescue
      e ->
        Logger.error("Error parsing chunk: #{inspect(e)}")
        {:error, "Failed to parse chunk: #{Exception.message(e)}"}
    end
  end

  def decode(""), do: nil
  def decode("[DONE]"), do: nil

  def decode(data) do
    try do
      Jason.decode!(data)
    rescue
      e ->
        Logger.error("JSON decode error: #{inspect(e)}, data: #{inspect(data)}")
        nil
    end
  end
end
