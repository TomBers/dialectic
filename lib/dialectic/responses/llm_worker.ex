defmodule Dialectic.Workers.LLMWorker do
  @moduledoc """
  Provider-agnostic LLM worker built on ReqLLM.

  This worker centralizes the streaming logic and delegates all provider-specific
  concerns (API key, model, provider_options, timeouts) to modules that implement
  the `Dialectic.LLM.Provider` behaviour. This allows you to plug in providers
  like OpenAI or Google (Gemini) without changing the streaming pipeline.

  Provider selection:
    - Prefer the job arg `"provider"` if present (e.g. "google", "openai").
    - Otherwise, use `System.get_env("LLM_PROVIDER")`.
    - Defaults to OpenAI.

  Expected job args:
    - "question" (string)
    - "to_node" (node id)
    - "graph" (graph id)
    - "live_view_topic" (PubSub topic for the LiveView)
    - Optional: "provider" (string: "openai" | "google" | "gemini")

  Notes:
    - This module is designed to replace the previous OpenAI-specific worker.
    - Uses a generic queue name (`:llm_request`) shared by all providers.
  """

  # Use a generic LLM queue shared by all providers.
  use Oban.Worker, queue: :llm_request, max_attempts: 5, priority: 0

  require Logger

  alias Dialectic.Responses.Utils
  alias Dialectic.DbActions.DbWorker
  alias Dialectic.Responses.{PromptsStructured, PromptsCreative, ModeServer}

  # -- Oban Perform Callback ----------------------------------------------------

  @impl Oban.Worker
  def perform(%Oban.Job{
        id: job_id,
        attempt: attempt,
        max_attempts: max_attempts,
        args:
          %{
            "question" => question,
            "to_node" => to_node,
            "graph" => graph,
            "live_view_topic" => live_view_topic
          } = args
      }) do
    Logger.metadata(oban_job_id: job_id, oban_attempt: attempt)

    provider_mod = select_provider(args)

    # Validate configuration early to surface clear messages
    {api_key_ok?, api_key_val} =
      case Dialectic.LLM.Provider.api_key(provider_mod) do
        {:ok, key} -> {true, key}
        {:error, :missing} -> {false, nil}
        {:error, :empty} -> {false, ""}
      end

    if not api_key_ok? do
      Phoenix.PubSub.broadcast(
        Dialectic.PubSub,
        live_view_topic,
        {:stream_error, "#{provider_label(provider_mod)} API key not configured", :node_id,
         to_node}
      )

      {:discard, :missing_api_key}
    else
      model_spec = Dialectic.LLM.Provider.model_spec(provider_mod)
      {_provider, _model, _opts} = model_spec

      # Build a provider-agnostic chat context: system + user
      system_prompt = get_system_prompt(graph)

      ctx =
        ReqLLM.Context.new([
          ReqLLM.Context.system(system_prompt),
          ReqLLM.Context.user(question)
        ])

      {connect_timeout, receive_timeout} = Dialectic.LLM.Provider.timeouts(provider_mod)
      finch_name = Dialectic.LLM.Provider.finch_name(provider_mod)
      provider_options = provider_mod.provider_options()

      case ReqLLM.stream_text(
             model_spec,
             ctx,
             api_key: api_key_val,
             finch_name: finch_name,
             provider_options: provider_options,
             connect_timeout: connect_timeout,
             receive_timeout: receive_timeout
           ) do
        {:ok, stream_resp} ->
          # Stream tokens to UI (and persisted vertex content) as they arrive.
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
            Logger.warning(
              "#{provider_label(provider_mod)} stream yielded no tokens; will retry (empty_stream)"
            )

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
                _ -> "#{provider_label(provider_mod)} request error: #{inspect(err)}"
              end

            Phoenix.PubSub.broadcast(
              Dialectic.PubSub,
              live_view_topic,
              {:stream_error, reason_msg, :node_id, to_node}
            )
          end

          Logger.error("#{provider_label(provider_mod)} request error: #{inspect(err)}")
          {:error, err}
      end
    end
  rescue
    exception ->
      Logger.error("LLM worker exception: #{Exception.format(:error, exception, __STACKTRACE__)}")

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
      Enum.find(Range.new(max, 0, -1), fn k ->
        String.ends_with?(acc, binary_part(chunk, 0, k))
      end) || 0

    binary_part(chunk, overlap, byte_size(chunk) - overlap)
  end

  defp get_system_prompt(graph_id) do
    case ModeServer.get_mode(graph_id) do
      :creative -> PromptsCreative.system_preamble()
      _ -> PromptsStructured.system_preamble()
    end
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

  # Prefer arg "provider" (string), else env LLM_PROVIDER, else default :openai
  defp select_provider(%{"provider" => p}) when is_binary(p), do: provider_module_from_string(p)

  defp select_provider(_args) do
    case System.get_env("LLM_PROVIDER") do
      nil -> Dialectic.LLM.Providers.OpenAI
      "" -> Dialectic.LLM.Providers.OpenAI
      p when is_binary(p) -> provider_module_from_string(p)
    end
  end

  defp provider_module_from_string(p) when is_binary(p) do
    case String.downcase(String.trim(p)) do
      "google" -> Dialectic.LLM.Providers.Google
      "gemini" -> Dialectic.LLM.Providers.Google
      "openai" -> Dialectic.LLM.Providers.OpenAI
      # Fallback
      _ -> Dialectic.LLM.Providers.OpenAI
    end
  end

  defp provider_label(mod) do
    case mod.id() do
      :google -> "Google"
      :openai -> "OpenAI"
      other -> to_string(other)
    end
  end
end
