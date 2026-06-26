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
            "question" => _question,
            "to_node" => to_node,
            "graph" => graph,
            "live_view_topic" => live_view_topic
          } = args
      }) do
    Logger.metadata(oban_job_id: job_id, oban_attempt: attempt)

    Logger.debug(fn ->
      "[LLMWorker] Starting job_id=#{job_id} attempt=#{attempt} graph=#{inspect(graph)} node=#{inspect(to_node)}"
    end)

    # Ensure the graph is loaded
    GraphManager.get_graph(graph)

    # Check if node already has content (another job may have completed)
    # This prevents duplicate jobs from overwriting each other's work
    existing_node = GraphManager.find_node_by_id(graph, to_node)
    existing_content = existing_node && Map.get(existing_node, :content, "")

    if is_binary(existing_content) and byte_size(existing_content) > 50 do
      Logger.warning(fn ->
        "[LLMWorker] SKIPPING job_id=#{job_id} - node #{to_node} already has content (#{byte_size(existing_content)} bytes). Another job likely completed first."
      end)

      # Return :ok to mark job as complete without doing work
      :ok
    else
      # Clear content for fresh start (idempotency for retries)
      GraphManager.set_node_content(graph, to_node, "")
      start_time = System.monotonic_time(:millisecond)

      do_llm_request(
        job_id,
        start_time,
        attempt,
        max_attempts,
        args,
        graph,
        to_node,
        live_view_topic
      )
    end
  end

  # Extracted LLM request logic to separate function for clarity
  defp do_llm_request(
         job_id,
         start_time,
         attempt,
         max_attempts,
         args,
         graph,
         to_node,
         live_view_topic
       ) do
    question = Map.get(args, "question", "")

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
             max_tokens: 4096,
             provider_options: provider_options,
             req_http_options: [connect_options: [timeout: connect_timeout]],
             receive_timeout: receive_timeout
           ) do
        {:ok, stream_resp} ->
          # Stream tokens to UI (and persisted vertex content) as they arrive.
          # We accumulate the *full* response text in the worker to ensure
          # we can safely overwrite the node content (bullet-proofing against
          # lost partial updates or GraphManager restarts).
          # Track timing: {full_text, buffer, first_token_logged?}
          {final_full_text, final_buf, _} =
            Enum.reduce(ReqLLM.StreamResponse.tokens(stream_resp), {"", "", false}, fn token,
                                                                                       {full_text,
                                                                                        buf,
                                                                                        ttft_logged?} ->
              chunk =
                case token do
                  t when is_binary(t) -> t
                  t when is_list(t) -> IO.iodata_to_binary(t)
                  t -> to_string(t)
                end

              # Log time-to-first-token (TTFT) on first chunk
              ttft_logged? =
                if not ttft_logged? and byte_size(chunk) > 0 do
                  ttft_ms = System.monotonic_time(:millisecond) - start_time
                  Logger.info("[LLMWorker] job_id=#{job_id} TTFT=#{ttft_ms}ms")
                  true
                else
                  ttft_logged?
                end

              new_full_text = full_text <> chunk
              new_buf = buf <> chunk

              # Buffer to reduce broadcast frequency (fixing markdown glitches and excessive DOM updates).
              # Flush if > @buffer_size chars or contains newline.
              # ALSO: Always flush the very first chunk (full_text was empty) to improve TTFT.
              if full_text == "" or byte_size(new_buf) > @buffer_size or
                   String.contains?(new_buf, "\n") do
                Utils.set_node_content(graph, to_node, new_full_text, live_view_topic)
                {new_full_text, "", ttft_logged?}
              else
                {new_full_text, new_buf, ttft_logged?}
              end
            end)

          # Flush remaining buffer (ensure final state matches full accumulation)
          if final_buf != "" do
            Utils.set_node_content(graph, to_node, final_full_text, live_view_topic)
          end

          finish_reason = ReqLLM.StreamResponse.finish_reason(stream_resp)

          cond do
            byte_size(final_full_text) == 0 ->
              Logger.warning(
                "#{provider_label(provider_mod)} stream yielded no tokens; will retry (empty_stream)"
              )

              {:error, :empty_stream}

            incomplete_finish?(finish_reason) ->
              Logger.warning(
                "[LLMWorker] job_id=#{job_id} stopped before completion finish_reason=#{inspect(finish_reason)} bytes=#{byte_size(final_full_text)}"
              )

              {:error, {:incomplete_stream, finish_reason}}

            missing_required_follow_ups?(instruction, final_full_text) ->
              final_full_text = append_fallback_follow_ups(final_full_text, instruction)
              Utils.set_node_content(graph, to_node, final_full_text, live_view_topic)

              total_ms = System.monotonic_time(:millisecond) - start_time

              Logger.warning(
                "[LLMWorker] job_id=#{job_id} completed without required follow-ups; appended fallback follow-up questions total=#{total_ms}ms bytes=#{byte_size(final_full_text)} finish_reason=#{inspect(finish_reason)}"
              )

              finalize(graph, to_node, live_view_topic)
              :ok

            true ->
              total_ms = System.monotonic_time(:millisecond) - start_time

              Logger.info(
                "[LLMWorker] job_id=#{job_id} completed total=#{total_ms}ms bytes=#{byte_size(final_full_text)} finish_reason=#{inspect(finish_reason)}"
              )

              finalize(graph, to_node, live_view_topic)
              :ok
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
  end

  # Note: Exceptions in do_llm_request will propagate up to perform/1

  defp incomplete_finish?(finish_reason) do
    finish_reason in [:length, :incomplete, :cancelled, :error, :content_filter]
  end

  defp missing_required_follow_ups?(instruction, text) do
    initial_explainer_request?(instruction) and not has_follow_up_questions?(text)
  end

  defp initial_explainer_request?(instruction) do
    is_binary(instruction) and
      String.contains?(instruction, "exact heading `## Follow-up questions`")
  end

  defp has_follow_up_questions?(text) when is_binary(text) do
    case split_at_follow_up_section(text) do
      {_before, body} ->
        lines =
          body
          |> String.split("\n")
          |> Enum.map(&String.trim/1)
          |> Enum.reject(&(&1 == ""))

        length(lines) == 3 and Enum.all?(lines, &numbered_question_line?/1)

      :not_found ->
        false
    end
  end

  defp has_follow_up_questions?(_text), do: false

  defp numbered_question_line?(line) do
    Regex.match?(~r/^\d+[\.)]\s+.+\?$/, line)
  end

  defp append_fallback_follow_ups(text, instruction) do
    topic = extract_initial_topic(instruction)
    text = strip_follow_up_section(text)

    questions = [
      "What historical context most changes how we should understand #{topic}?",
      "Which interpretation of #{topic} is most contested, and why?",
      "What detail about #{topic} would be most rewarding to explore next?"
    ]

    [
      String.trim_trailing(text),
      "## Follow-up questions",
      "1. #{Enum.at(questions, 0)}",
      "2. #{Enum.at(questions, 1)}",
      "3. #{Enum.at(questions, 2)}"
    ]
    |> Enum.join("\n\n")
  end

  defp strip_follow_up_section(text) do
    case split_at_follow_up_section(text) do
      {before, _body} -> String.trim_trailing(before)
      :not_found -> String.trim_trailing(text)
    end
  end

  defp split_at_follow_up_section(text) do
    case Regex.split(~r/^##\s+Follow-up questions\s*$/im, text, parts: 2) do
      [before, body] -> {before, body}
      [_text] -> :not_found
    end
  end

  defp extract_initial_topic(instruction) do
    case Regex.run(~r/\*\*Your task:\*\* Answer \*\*(?<topic>.*?)\*\*/s, instruction,
           capture: ["topic"]
         ) do
      [topic] -> topic |> String.replace(~r/\s+/, " ") |> String.trim()
      _ -> "this topic"
    end
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
