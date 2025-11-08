defmodule Dialectic.Workers.OpenAIWorker do
  @moduledoc """
  OpenAI worker implemented with req_llm's high-level streaming API.

  This refactor removes custom HTTP/SSE plumbing. It relies on:
  - ReqLLM.stream_text/3 for provider-agnostic streaming
  - ReqLLM.StreamResponse.tokens/1 to enumerate text tokens
  - Existing Utils.process_chunk/5 to append streamed tokens and broadcast to LiveView
  - Finalization identical to prior behavior (finalize node content, save graph, PubSub completion)
  """

  use Oban.Worker, queue: :openai_request, max_attempts: 5, priority: 0

  require Logger

  alias Dialectic.Responses.Utils
  alias Dialectic.DbActions.DbWorker

  @system_prompt """
  You are an expert philosopher, helping the user better understand key philosophical points.
  Keep answers concise and to the point. Add references to sources when appropriate.
  """

  # -- Oban Perform Callback ----------------------------------------------------

  @impl Oban.Worker
  def perform(%Oban.Job{
        id: job_id,
        attempt: attempt,
        args:
          args = %{
            "question" => question,
            "to_node" => to_node,
            "graph" => graph,
            "live_view_topic" => live_view_topic
          }
      }) do
    Logger.metadata(oban_job_id: job_id, oban_attempt: attempt)
    # Timing instrumentation
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
      "llm_timing perform_start queue_ms=#{inspect(queue_ms)} graph=#{inspect(graph)} node=#{inspect(to_node)} job_id=#{inspect(job_id)} attempt=#{inspect(attempt)}"
    )

    model_spec = openai_model_spec()
    {provider, model, opts} = model_spec
    provider_options = Keyword.get(opts, :provider_options)
    api_key = System.get_env("OPENAI_API_KEY")

    # Build a provider-agnostic chat context: system + user
    ctx =
      ReqLLM.Context.new([
        ReqLLM.Context.system(@system_prompt),
        ReqLLM.Context.user(question)
      ])

    # Stream text – this returns a StreamResponse handle
    request_start_ms = System.monotonic_time(:millisecond)

    Logger.info(
      "llm_timing request_start provider=#{provider} model=#{model} provider_options=#{inspect(provider_options)} setup_ms=#{request_start_ms - perform_start_ms} graph=#{inspect(graph)} node=#{inspect(to_node)} job_id=#{inspect(job_id)} attempt=#{inspect(attempt)}"
    )

    case ReqLLM.stream_text(
           model_spec,
           ctx,
           api_key: api_key,
           finch_name: ReqLLM.Finch,
           provider_options: [
             reasoning_effort: :minimal,
             openai_parallel_tool_calls: false
           ],
           connect_timeout: 60_000,
           receive_timeout: 300_000
         ) do
      {:ok, stream_resp} ->
        headers_received_ms = System.monotonic_time(:millisecond) - request_start_ms

        Logger.info(
          "llm_timing headers_received headers_received_ms=#{headers_received_ms} graph=#{inspect(graph)} node=#{inspect(to_node)} job_id=#{inspect(job_id)} attempt=#{inspect(attempt)}"
        )

        # Stream tokens to UI (and persisted vertex content) as they arrive
        _seen? =
          Enum.reduce(ReqLLM.StreamResponse.tokens(stream_resp), false, fn token, seen? ->
            unless seen? do
              ttft_ms = System.monotonic_time(:millisecond) - request_start_ms

              Logger.info(
                "llm_timing first_token ttft_ms=#{ttft_ms} graph=#{inspect(graph)} node=#{inspect(to_node)} job_id=#{inspect(job_id)} attempt=#{inspect(attempt)}"
              )
            end

            Utils.process_chunk(graph, to_node, token, __MODULE__, live_view_topic)
            true
          end)

        stream_end_ms = System.monotonic_time(:millisecond)

        Logger.info(
          "llm_timing stream_end request_ms=#{stream_end_ms - request_start_ms} graph=#{inspect(graph)} node=#{inspect(to_node)} job_id=#{inspect(job_id)} attempt=#{inspect(attempt)}"
        )

        Logger.info(
          "llm_timing finalize_start graph=#{inspect(graph)} node=#{inspect(to_node)} job_id=#{inspect(job_id)} attempt=#{inspect(attempt)}"
        )

        finalize(graph, to_node, live_view_topic)
        finalize_end_ms = System.monotonic_time(:millisecond)

        total_since_enqueue_ms =
          if is_integer(queued_at_ms) do
            System.system_time(:millisecond) - queued_at_ms
          else
            nil
          end

        Logger.info(
          "llm_timing finalize_end finalize_ms=#{finalize_end_ms - stream_end_ms} total_ms_since_perform=#{finalize_end_ms - perform_start_ms} total_since_enqueue_ms=#{inspect(total_since_enqueue_ms)} job_id=#{inspect(job_id)} attempt=#{inspect(attempt)}"
        )

        :ok

      {:error, err} ->
        err_ms = System.monotonic_time(:millisecond)

        Logger.error(
          "llm_timing request_error elapsed_ms=#{err_ms - request_start_ms} provider=#{provider} model=#{model} graph=#{inspect(graph)} node=#{inspect(to_node)} job_id=#{inspect(job_id)} attempt=#{inspect(attempt)} error=#{inspect(err)}"
        )

        {:error, err}
    end
  rescue
    exception ->
      Logger.error(
        "OpenAI worker exception: #{Exception.format(:error, exception, __STACKTRACE__)}"
      )

      reraise exception, __STACKTRACE__
  end

  # -- Internals ----------------------------------------------------------------

  defp openai_model_spec do
    # Hardcoded model per request (favor fast TTFT for diagnosis)
    # TODO: make this configurable via config/runtime.exs or OPENAI_CHAT_MODEL
    {:openai, "gpt-5-nano",
     provider_options: [
       reasoning_effort: :minimal,
       openai_parallel_tool_calls: false
     ]}
  end

  defp finalize(graph, to_node, live_view_topic) do
    GraphManager.finalize_node_content(graph, to_node)
    DbWorker.save_graph(graph, false)

    Phoenix.PubSub.broadcast(
      Dialectic.PubSub,
      live_view_topic,
      {:llm_request_complete, to_node}
    )
  end
end
