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

  # -- Oban Perform Callback ----------------------------------------------------

  @impl Oban.Worker
  def perform(%Oban.Job{
        id: job_id,
        attempt: attempt,
        max_attempts: max_attempts,
        args: %{
          "question" => question,
          "to_node" => to_node,
          "graph" => graph,
          "live_view_topic" => live_view_topic
        }
      }) do
    Logger.metadata(oban_job_id: job_id, oban_attempt: attempt)

    api_key = fetch_openai_api_key()

    if is_nil(api_key) or api_key == "" do
      Phoenix.PubSub.broadcast(
        Dialectic.PubSub,
        live_view_topic,
        {:stream_error, "OpenAI API key not configured", :node_id, to_node}
      )

      {:discard, :missing_api_key}
    else
      model_spec = openai_model_spec()
      {_provider, _model, _opts} = model_spec

      # Build a provider-agnostic chat context: system + user
      # TODO: get system prompt depending on the mode selected.
      system_prompt = "TODO"

      ctx =
        ReqLLM.Context.new([
          ReqLLM.Context.system(system_prompt),
          ReqLLM.Context.user(question)
        ])

      # Stream text – this returns a StreamResponse handle
      case ReqLLM.stream_text(
             model_spec,
             ctx,
             api_key: api_key,
             finch_name: Dialectic.Finch,
             provider_options: [
               reasoning_effort: :minimal,
               openai_parallel_tool_calls: false
             ],
             connect_timeout: 60_000,
             receive_timeout: 300_000
           ) do
        {:ok, stream_resp} ->
          # Stream tokens to UI (and persisted vertex content) as they arrive.
          # Track how many bytes were appended; treat empty streams as transient failures.
          {_final, appended_len} =
            Enum.reduce(ReqLLM.StreamResponse.tokens(stream_resp), {"", 0}, fn token, {acc, n} ->
              chunk =
                cond do
                  is_binary(token) -> token
                  is_list(token) -> IO.iodata_to_binary(token)
                  true -> to_string(token)
                end

              to_emit = diff_suffix(acc, chunk)

              if to_emit != "" do
                Utils.process_chunk(graph, to_node, to_emit, __MODULE__, live_view_topic)
              end

              {acc <> to_emit, n + byte_size(to_emit)}
            end)

          if appended_len > 0 do
            finalize(graph, to_node, live_view_topic)
            :ok
          else
            Logger.warning("OpenAI stream yielded no tokens; will retry (empty_stream)")
            {:error, :empty_stream}
          end

        {:error, err} ->
          # Only broadcast an error to the UI on the final attempt; let Oban retry transiently.
          final? = attempt >= max_attempts

          if final? do
            reason_msg =
              case err do
                %Mint.TransportError{reason: r} -> "Network error (transport): #{inspect(r)}"
                :empty_stream -> "Model returned an empty stream"
                _ -> "OpenAI request error: #{inspect(err)}"
              end

            Phoenix.PubSub.broadcast(
              Dialectic.PubSub,
              live_view_topic,
              {:stream_error, reason_msg, :node_id, to_node}
            )
          end

          Logger.error("OpenAI request error: #{inspect(err)}")
          {:error, err}
      end
    end
  rescue
    exception ->
      Logger.error(
        "OpenAI worker exception: #{Exception.format(:error, exception, __STACKTRACE__)}"
      )

      reraise exception, __STACKTRACE__
  end

  # -- Internals ----------------------------------------------------------------

  # Compute only the unseen suffix of `chunk` relative to what we've already emitted in `acc`.
  # Handles both incremental token streams and cumulative "full text so far" streams,
  # and is robust to small prefix/suffix overlaps between chunks.
  defp diff_suffix("", chunk) when is_binary(chunk), do: chunk

  defp diff_suffix(acc, chunk) when is_binary(acc) and is_binary(chunk) do
    max = min(byte_size(acc), byte_size(chunk))

    overlap =
      Enum.find(max..0, fn k ->
        String.ends_with?(acc, binary_part(chunk, 0, k))
      end) || 0

    binary_part(chunk, overlap, byte_size(chunk) - overlap)
  end

  defp fetch_openai_api_key do
    System.get_env("OPENAI_API_KEY")
  end

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
