defmodule Dialectic.Workers.LocalWorker do
  require Logger
  use Oban.Worker, queue: :api_request, max_attempts: 5

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
    # Timing instrumentation for test/local flow
    queued_at_ms = Map.get(args, "queued_at_ms")
    perform_start_wall_ms = System.system_time(:millisecond)

    queue_ms =
      if is_integer(queued_at_ms) do
        perform_start_wall_ms - queued_at_ms
      else
        nil
      end

    perform_start_ms = System.monotonic_time(:millisecond)

    Logger.info(
      "llm_timing perform_start queue_ms=#{inspect(queue_ms)} graph=#{inspect(graph)} node=#{inspect(node)}"
    )

    provider = :local
    model = "echo"

    request_start_ms = System.monotonic_time(:millisecond)

    Logger.info(
      "llm_timing request_start provider=#{provider} model=#{model} setup_ms=#{request_start_ms - perform_start_ms} graph=#{inspect(graph)} node=#{inspect(node)}"
    )

    # Local worker returns immediately, simulate first token timing
    ttft_ms = System.monotonic_time(:millisecond) - request_start_ms

    Logger.info(
      "llm_timing first_token ttft_ms=#{ttft_ms} graph=#{inspect(graph)} node=#{inspect(node)}"
    )

    updated_vertex = GraphManager.update_vertex(graph, node, question)

    Phoenix.PubSub.broadcast(
      Dialectic.PubSub,
      live_view_topic,
      {:stream_chunk, updated_vertex, :node_id, node}
    )

    stream_end_ms = System.monotonic_time(:millisecond)

    Logger.info(
      "llm_timing stream_end request_ms=#{stream_end_ms - request_start_ms} graph=#{inspect(graph)} node=#{inspect(node)}"
    )

    Logger.info("llm_timing finalize_start graph=#{inspect(graph)} node=#{inspect(node)}")

    Phoenix.PubSub.broadcast(
      Dialectic.PubSub,
      live_view_topic,
      {:llm_request_complete, node}
    )

    finalize_end_ms = System.monotonic_time(:millisecond)

    total_since_enqueue_ms =
      if is_integer(queued_at_ms) do
        System.system_time(:millisecond) - queued_at_ms
      else
        nil
      end

    Logger.info(
      "llm_timing finalize_end finalize_ms=#{finalize_end_ms - stream_end_ms} total_ms_since_perform=#{finalize_end_ms - perform_start_ms} total_since_enqueue_ms=#{inspect(total_since_enqueue_ms)}"
    )
  end
end
