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
  alias Dialectic.Responses.{PromptsStructured, ModeServer}

  @buffer_size 50

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

    # Ensure the graph is loaded and the node content is cleared (idempotency)
    GraphManager.get_graph(graph)
    GraphManager.set_node_content(graph, to_node, "")

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

      # Build a provider-agnostic chat context: system + user
      system_prompt =
        case Map.get(args, "system_prompt") do
          s when is_binary(s) and s != "" -> s
          _ -> get_system_prompt(graph)
        end

      instruction =
        case Map.get(args, "instruction") do
          s when is_binary(s) and s != "" -> s
          _ -> question
        end

      ctx =
        ReqLLM.Context.new([
          ReqLLM.Context.system(system_prompt),
          ReqLLM.Context.user(instruction)
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
             req_http_options: [connect_options: [timeout: connect_timeout]],
             receive_timeout: receive_timeout
           ) do
        {:ok, stream_resp} ->
          # Stream tokens to UI (and persisted vertex content) as they arrive.
          # We accumulate the *full* response text in the worker to ensure
          # we can safely overwrite the node content (bullet-proofing against
          # lost partial updates or GraphManager restarts).
          {final_full_text, final_buf} =
            Enum.reduce(ReqLLM.StreamResponse.tokens(stream_resp), {"", ""}, fn token,
                                                                                {full_text, buf} ->
              chunk =
                case token do
                  t when is_binary(t) -> t
                  t when is_list(t) -> IO.iodata_to_binary(t)
                  t -> to_string(t)
                end

              new_full_text = full_text <> chunk
              new_buf = buf <> chunk

              # Buffer to reduce broadcast frequency (fixing markdown glitches and excessive DOM updates).
              # Flush if > @buffer_size chars or contains newline.
              # ALSO: Always flush the very first chunk (full_text was empty) to improve TTFT.
              if full_text == "" or byte_size(new_buf) > @buffer_size or
                   String.contains?(new_buf, "\n") do
                Utils.set_node_content(graph, to_node, new_full_text, live_view_topic)
                {new_full_text, ""}
              else
                {new_full_text, new_buf}
              end
            end)

          # Flush remaining buffer (ensure final state matches full accumulation)
          if final_buf != "" do
            Utils.set_node_content(graph, to_node, final_full_text, live_view_topic)
          end

          if byte_size(final_full_text) > 0 do
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

  defp get_system_prompt(graph_id) do
    mode = ModeServer.get_mode(graph_id)
    PromptsStructured.system_preamble(mode)
  end

  defp finalize(graph, to_node, live_view_topic) do
    GraphManager.finalize_node_content(graph, to_node)
    GraphManager.save_graph(graph)

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
