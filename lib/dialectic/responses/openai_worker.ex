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

  # Prefer explicit provider tuple to avoid relying on "provider:model" parsing,
  # and to keep compatibility if OPENAI_MODEL is a bare model name.
  @default_openai_model "gpt-4o-mini"
  @system_prompt """
  You are an expert philosopher, helping the user better understand key philosophical points.
  Keep answers concise and to the point. Add references to sources when appropriate.
  """

  # -- Oban Perform Callback ----------------------------------------------------

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{
          "question" => question,
          "to_node" => to_node,
          "graph" => graph,
          "live_view_topic" => live_view_topic
        }
      }) do
    model_spec = openai_model_spec()
    api_key = System.get_env("OPENAI_API_KEY")

    # Build a provider-agnostic chat context: system + user
    ctx =
      ReqLLM.Context.new([
        ReqLLM.Context.system(@system_prompt),
        ReqLLM.Context.user(question)
      ])

    # Stream text – this returns a StreamResponse handle
    case ReqLLM.stream_text(model_spec, ctx, api_key: api_key) do
      {:ok, stream_resp} ->
        # Stream tokens to UI (and persisted vertex content) as they arrive
        ReqLLM.StreamResponse.tokens(stream_resp)
        |> Stream.each(fn token ->
          Utils.process_chunk(graph, to_node, token, __MODULE__, live_view_topic)
        end)
        |> Stream.run()

        finalize(graph, to_node, live_view_topic)
        :ok

      {:error, err} ->
        Logger.error("OpenAI streaming error: #{inspect(err)}")
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
    # Allow override via OPENAI_MODEL; default to a widely available model
    # We use the {:provider, "model", opts} tuple form supported by ReqLLM.
    raw = System.get_env("OPENAI_MODEL") || @default_openai_model
    {:openai, raw, []}
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
