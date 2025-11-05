defmodule Dialectic.Workers.LocalWorker do
  require Logger
  use Oban.Worker, queue: :api_request, max_attempts: 5

  def perform(%Oban.Job{
        args: %{
          "question" => question,
          "to_node" => node,
          "graph" => graph,
          "module" => _worker_module,
          "live_view_topic" => live_view_topic
        }
      }) do
    IO.inspect("Local processing for graph #{graph} and node #{node}. Data: #{question}",
      label: "Local Processing"
    )

    updated_vertex = GraphManager.update_vertex(graph, node, question)

    Phoenix.PubSub.broadcast(
      Dialectic.PubSub,
      live_view_topic,
      {:llm_text, updated_vertex, :node_id, node}
    )

    Phoenix.PubSub.broadcast(
      Dialectic.PubSub,
      live_view_topic,
      {:llm_request_complete, node}
    )
  end
end
