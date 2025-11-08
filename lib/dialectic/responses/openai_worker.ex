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
        # Stream tokens to UI (and persisted vertex content) as they arrive
        _seen? =
          Enum.reduce(ReqLLM.StreamResponse.tokens(stream_resp), false, fn token, seen? ->
            unless seen? do
            end

            Utils.process_chunk(graph, to_node, token, __MODULE__, live_view_topic)
            true
          end)

        finalize(graph, to_node, live_view_topic)
        :ok

      {:error, err} ->
        Logger.error("OpenAI request error: #{inspect(err)}")
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
    {:openai, "gpt-5-nano", []}
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
