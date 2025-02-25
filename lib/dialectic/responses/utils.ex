defmodule Dialectic.Responses.Utils do
  require Logger

  def process_chunk(graph, node, data, _module) do
    Logger.info("Processing chunk for graph #{graph} and node #{node}. Data: #{data}")

    Phoenix.PubSub.broadcast(
      Dialectic.PubSub,
      graph,
      {:stream_chunk, data, :node_id, node}
    )
  end

  def parse_chunk(chunk) do
    try do
      chunks =
        chunk
        |> String.split("data: ")
        |> Enum.map(&String.trim/1)
        |> Enum.map(&decode/1)
        |> Enum.reject(&is_nil/1)

      {:ok, chunks}
    rescue
      e ->
        Logger.error("Error parsing chunk: #{inspect(e)}")
        {:error, "Failed to parse chunk"}
    end
  end

  def decode(""), do: nil
  def decode("[DONE]"), do: nil

  def decode(data) do
    try do
      Jason.decode!(data)
    rescue
      _ -> nil
    end
  end
end
