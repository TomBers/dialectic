defmodule Dialectic.Workers.LocalWorker do
  require Logger
  use Oban.Worker, queue: :api_request, max_attempts: 5
  # Note: LocalWorker ignores any optional "instruction" and "system_prompt" args.
  # Tests and dev flows continue to rely on the "question" arg for echo behavior.

  def perform(%Oban.Job{
        args:
          args = %{
            "question" => question,
            "to_node" => node,
            "graph" => graph,
            "module" => _worker_module,
            "live_view_topic" => live_view_topic
          }
      }) do
    # Explicitly ignore optional instruction/system_prompt keys if present
    _ = Map.get(args, "instruction")
    _ = Map.get(args, "system_prompt")
    updated_vertex = GraphManager.update_vertex(graph, node, question)

    # Broadcast :stream_chunk_broadcast directly with nil sender_pid to avoid
    # amplification. When using :stream_chunk, each subscribed LiveView would
    # re-broadcast to the same topic, causing N^2 messages with N clients.
    Phoenix.PubSub.broadcast(
      Dialectic.PubSub,
      live_view_topic,
      {:stream_chunk_broadcast, updated_vertex, :node_id, node, nil}
    )

    Phoenix.PubSub.broadcast(
      Dialectic.PubSub,
      live_view_topic,
      {:llm_request_complete, node}
    )
  end
end
