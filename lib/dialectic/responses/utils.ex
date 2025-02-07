defmodule Dialectic.Responses.Utils do
  def process_chunk(graph, node, data, module) do
    File.write("#{module}.txt", "#{data}\n", [:append])
    # Phoenix.PubSub.broadcast(
    #   Dialectic.PubSub,
    #   graph,
    #   {:stream_chunk, data, :node_id, node}
    # )
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
