defmodule Dialectic.Responses.Utils do
  require Logger

  def process_chunk(graph, node, data, _module, live_view_topic) do
    Logger.debug(fn -> "Processing chunk for graph #{graph} and node #{node}. Data: #{data}" end)
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
      case :binary.match(chunk, "data: ") do
        :nomatch ->
          {:ok, []}

        _ ->
          segments = :binary.split(chunk, "data: ", [:global])

          chunks =
            segments
            |> Enum.drop(1)
            |> Enum.reduce([], fn seg, acc ->
              first =
                case :binary.split(seg, "\n") do
                  [h | _] -> String.trim(h)
                  [] -> String.trim(seg)
                end

              case decode(first) do
                nil -> acc
                decoded -> [decoded | acc]
              end
            end)
            |> Enum.reverse()

          if chunks == [] do
            {:ok, []}
          else
            error_chunk =
              Enum.find(chunks, fn
                %{"error" => _} -> true
                _ -> false
              end)

            if error_chunk do
              Logger.error("Error in chunk response: #{inspect(error_chunk)}")
            end

            {:ok, chunks}
          end
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
