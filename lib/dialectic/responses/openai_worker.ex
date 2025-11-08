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
        args: %{
          "question" => question,
          "to_node" => to_node,
          "graph" => graph,
          "live_view_topic" => live_view_topic
        }
      }) do
    Logger.metadata(oban_job_id: job_id, oban_attempt: attempt)

    model_spec = openai_model_spec()
    {_provider, _model, _opts} = model_spec
    api_key = System.get_env("OPENAI_API_KEY")

    # Build a provider-agnostic chat context: system + user
    ctx =
      ReqLLM.Context.new([
        ReqLLM.Context.system("""
        You must return valid GitHub-flavored Markdown (GFM) only.

        Rules:
        - Use headings with a space after the hashes (e.g., '### Title'), never '###. Title' or '###Title'.
        - Numbered lists must use '1.' '2.' etc., each on its own line, with a space after the period.
        - Leave a blank line before any heading or list block.
        - Do not use '1)' or '(1)' for lists.
        - Do not insert headings mid-sentence.
        - No JSON or HTML wrappers in the answer; produce Markdown only.
        - Do not include literal escape sequences like '\n' in the output; emit real newlines.
        """),
        ReqLLM.Context.user(question)
      ])

    # Stream text – this returns a StreamResponse handle

    result =
      if is_nil(api_key) or api_key == "" do
        {:api_key_missing, :missing_api_key}
      else
        ReqLLM.stream_text(
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
        )
      end

    case result do
      {:api_key_missing, _} ->
        Phoenix.PubSub.broadcast(
          Dialectic.PubSub,
          live_view_topic,
          {:stream_error, "OpenAI API key not configured", :node_id, to_node}
        )

        {:discard, :missing_api_key}

      {:ok, stream_resp} ->
        # Stream tokens to UI (and persisted vertex content) as they arrive.
        # Guard against providers that resend cumulative content by appending only the new suffix.
        _acc =
          Enum.reduce(ReqLLM.StreamResponse.tokens(stream_resp), "", fn token, acc ->
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

            acc <> to_emit
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
