defmodule Dialectic.Workers.LocalWorker do
  require Logger
  use Oban.Worker, queue: :api_request, max_attempts: 5

  def perform(%Oban.Job{
        args: %{
          "question" => question,
          "to_node" => node,
          "graph" => graph,
          "module" => _worker_module
        }
      }) do
    IO.inspect("Local Processing chunk for graph #{graph} and node #{node}. Data: #{question}",
      label: "Local Processing"
    )

    updated_vertex = GraphManager.update_vertex(graph, node, question)

    Phoenix.PubSub.broadcast(
      Dialectic.PubSub,
      graph,
      {:stream_chunk, updated_vertex, :node_id, node}
    )
  end
end
