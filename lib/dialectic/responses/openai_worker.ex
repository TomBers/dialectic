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

  @stream_debug_env_key "E2E_STREAM_DEBUG"
  defp stream_debug? do
    Mix.env() != :prod and
      case System.get_env(@stream_debug_env_key) do
        "1" -> true
        "true" -> true
        "TRUE" -> true
        _ -> false
      end
  end

  alias Dialectic.Responses.Utils
  alias Dialectic.DbActions.DbWorker
  alias Dialectic.Responses.{PromptsStructured, PromptsCreative, ModeServer}

  # -- Oban Perform Callback ----------------------------------------------------

  @impl Oban.Worker
  def perform(%Oban.Job{
        id: _job_id,
        attempt: attempt,
        max_attempts: max_attempts,
        args: %{
          "question" => question,
          "to_node" => to_node,
          "graph" => graph,
          "live_view_topic" => live_view_topic
        }
      }) do
    # Logger.metadata(oban_job_id: job_id, oban_attempt: attempt)

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

      system_prompt = get_system_prompt(graph)

      ctx =
        ReqLLM.Context.new([
          ReqLLM.Context.system(system_prompt),
          ReqLLM.Context.user(question)
        ])

      # Debug logging: system + user prompt (truncated)
      _mode = ModeServer.get_mode(graph)
      {_prov, _model_name, _opts} = model_spec

      ## USED for Debugging
      # Logger.debug(fn ->
      #   sys_preview = String.slice(system_prompt || "", 0, 500)
      #   usr_preview = String.slice(question || "", 0, 500)

      #   "[OpenAIWorker] graph_id=#{inspect(graph)} mode=#{mode} model=#{model_name}\nSYSTEM_PROMPT_START\n#{sys_preview}\nSYSTEM_PROMPT_END\nUSER_PROMPT_START\n#{usr_preview}\nUSER_PROMPT_END"
      # end)

      # Stream text – this returns a StreamResponse handle
      if stream_debug?(),
        do:
          Logger.debug(
            "[openai] stream_start graph=#{inspect(graph)} node=#{inspect(to_node)} attempt=#{attempt}/#{max_attempts}"
          )

      case ReqLLM.stream_text(
             model_spec,
             ctx,
             api_key: api_key,
             finch_name: Dialectic.Finch,
             provider_options: [
               openai_parallel_tool_calls: false
             ],
             connect_timeout: 60_000,
             receive_timeout: 300_000
           ) do
        {:ok, stream_resp} ->
          if stream_debug?() do
            {prov, model_name, _} = model_spec
            Logger.debug("[openai] stream_opened provider=#{inspect(prov)} model=#{model_name}")
          end

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

          if stream_debug?(), do: Logger.debug("[openai] stream_complete bytes=#{appended_len}")

          if appended_len > 0 do
            finalize(graph, to_node, live_view_topic)
            :ok
          else
            Logger.warning("OpenAI stream yielded no tokens; will retry (empty_stream)")
            {:error, :empty_stream}
          end

        {:error, err} ->
          if stream_debug?(),
            do:
              Logger.debug(
                "[openai] stream_error err=#{inspect(err)} attempt=#{attempt}/#{max_attempts}"
              )

          reason_msg =
            case err do
              %Mint.TransportError{reason: r} -> "Network error (transport): #{inspect(r)}"
              :empty_stream -> "Model returned an empty stream"
              _ -> "OpenAI request error: #{inspect(err)}"
            end

          attempt_msg = "[attempt #{attempt}/#{max_attempts}] "

          Phoenix.PubSub.broadcast(
            Dialectic.PubSub,
            live_view_topic,
            {:stream_error, attempt_msg <> reason_msg, :node_id, to_node}
          )

          Logger.error(
            "OpenAI request error (attempt #{attempt}/#{max_attempts}): #{inspect(err)}"
          )

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
    cond do
      chunk == "" ->
        ""

      # Cumulative stream: chunk is the "full text so far"
      String.starts_with?(chunk, acc) ->
        binary_part(chunk, byte_size(acc), byte_size(chunk) - byte_size(acc))

      # Chunk is entirely already included in acc (e.g., resend of old prefix/suffix)
      String.starts_with?(acc, chunk) or String.ends_with?(acc, chunk) ->
        ""

      true ->
        # Heuristic overlap with a minimum threshold to avoid accidental matches on small tokens.
        max = min(byte_size(acc), byte_size(chunk))
        min_overlap = 12

        # Recompute an overlap safely and search from largest to smallest to prefer longest match.
        max_overlap = min(byte_size(acc), byte_size(chunk))

        overlap =
          if max_overlap < min_overlap do
            0
          else
            min_overlap..max_overlap
            |> Enum.reverse()
            |> Enum.find_value(fn k ->
              # k <= max_overlap <= byte_size(chunk); safe slice
              prefix = binary_part(chunk, 0, k)
              if String.ends_with?(acc, prefix), do: k, else: nil
            end)
            |> Kernel.||(0)
          end

        if overlap > 0 do
          binary_part(chunk, overlap, byte_size(chunk) - overlap)
        else
          # Treat as incremental token; emit as-is (prefer duplicates over dropped characters)
          chunk
        end
    end
  end

  defp fetch_openai_api_key do
    System.get_env("OPENAI_API_KEY")
  end

  defp openai_model_spec do
    # Hardcoded model per request (favor fast TTFT for diagnosis)
    # TODO: make this configurable via config/runtime.exs or OPENAI_CHAT_MODEL
    {:openai, "gpt-5.1-chat-latest", []}
  end

  defp get_system_prompt(graph_id) do
    case ModeServer.get_mode(graph_id) do
      :creative -> PromptsCreative.system_preamble()
      _ -> PromptsStructured.system_preamble()
    end
  end

  defp finalize(graph, to_node, live_view_topic) do
    if stream_debug?(),
      do: Logger.debug("[openai] finalize graph=#{inspect(graph)} node=#{inspect(to_node)}")

    GraphManager.finalize_node_content(graph, to_node)
    DbWorker.save_graph(graph, false, final: true)

    Phoenix.PubSub.broadcast(
      Dialectic.PubSub,
      live_view_topic,
      {:llm_request_complete, to_node}
    )
  end
end
