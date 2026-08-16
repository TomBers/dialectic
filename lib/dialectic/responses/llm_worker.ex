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
    - Defaults to Google Gemini.

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

  @buffer_size 200
  @stream_flush_min_interval_ms 100
  @stream_flush_max_interval_ms 500
  @queue_wait_event [:dialectic, :llm, :queue_wait]
  @time_to_first_token_event [:dialectic, :llm, :time_to_first_token]
  @job_event [:dialectic, :llm, :job]

  # -- Oban Perform Callback ----------------------------------------------------

  @impl Oban.Worker
  def backoff(%Oban.Job{
        unsaved_error: %{
          reason: %ReqLLM.Error.API.Stream{
            cause: %Finch.Error{reason: :connection_closed}
          }
        }
      }),
      do: 1

  def backoff(job), do: Oban.Worker.backoff(job)

  @impl Oban.Worker
  def perform(%Oban.Job{
        id: job_id,
        attempt: attempt,
        max_attempts: max_attempts,
        inserted_at: inserted_at,
        scheduled_at: scheduled_at,
        args:
          %{
            "question" => _question,
            "to_node" => to_node,
            "graph" => graph,
            "live_view_topic" => live_view_topic
          } = args
      }) do
    job_started_at = System.monotonic_time()
    queue_started_at = queue_reference_time(attempt, inserted_at, scheduled_at)
    queue_duration = queue_wait_duration(queue_started_at, System.system_time(:microsecond))
    provider_mod = select_provider(args)
    provider = provider_mod.id()

    if is_integer(queue_duration) do
      emit_queue_wait(queue_duration, provider, :started)

      Logger.info(
        "[LLMWorker] job_id=#{job_id} queue_wait=#{duration_in_milliseconds(queue_duration)}ms provider=#{provider}"
      )
    end

    try do
      Logger.metadata(oban_job_id: job_id, oban_attempt: attempt)

      Logger.debug(fn ->
        "[LLMWorker] Starting job_id=#{job_id} attempt=#{attempt} graph=#{inspect(graph)} node=#{inspect(to_node)}"
      end)

      {result, outcome} =
        perform_job(
          job_id,
          job_started_at,
          attempt,
          max_attempts,
          args,
          graph,
          to_node,
          live_view_topic,
          provider_mod
        )

      emit_completion_telemetry(job_started_at, provider, outcome)
      result
    catch
      kind, reason ->
        emit_completion_telemetry(job_started_at, provider, :exception)
        :erlang.raise(kind, reason, __STACKTRACE__)
    end
  end

  defp perform_job(
         job_id,
         job_started_at,
         attempt,
         max_attempts,
         args,
         graph,
         to_node,
         live_view_topic,
         provider_mod
       ) do
    GraphManager.get_graph(graph)

    existing_node = GraphManager.find_node_by_id(graph, to_node)
    existing_content = existing_node && Map.get(existing_node, :content, "")

    if skip_existing_response?(attempt, existing_content) do
      Logger.warning(fn ->
        "[LLMWorker] SKIPPING job_id=#{job_id} - node #{to_node} already has content (#{byte_size(existing_content)} bytes). Another job likely completed first."
      end)

      {:ok, :skipped}
    else
      GraphManager.set_node_content(graph, to_node, "")

      result =
        do_llm_request(
          job_id,
          job_started_at,
          args,
          graph,
          to_node,
          live_view_topic,
          provider_mod
        )

      if attempt >= max_attempts and match?({:error, _reason}, result) do
        persist_stream_error(
          graph,
          to_node,
          live_view_topic,
          terminal_error_message(provider_mod, result)
        )
      end

      {result, outcome_for_result(result)}
    end
  end

  # Extracted LLM request logic to separate function for clarity
  defp do_llm_request(
         job_id,
         job_started_at,
         args,
         graph,
         to_node,
         live_view_topic,
         provider_mod
       ) do
    question = Map.get(args, "question", "")

    # Validate configuration early to surface clear messages
    {api_key_ok?, api_key_val} =
      case Dialectic.LLM.Provider.api_key(provider_mod) do
        {:ok, key} -> {true, key}
        {:error, :missing} -> {false, nil}
        {:error, :empty} -> {false, ""}
      end

    if not api_key_ok? do
      persist_stream_error(
        graph,
        to_node,
        live_view_topic,
        "#{provider_label(provider_mod)} API key not configured"
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

      {_connect_timeout, receive_timeout} = Dialectic.LLM.Provider.timeouts(provider_mod)
      finch_name = Dialectic.LLM.Provider.finch_name(provider_mod)
      provider_options = provider_mod.provider_options()
      max_tokens = request_max_tokens(args, graph)
      request_started_at = System.monotonic_time()

      case ReqLLM.stream_text(
             model_spec,
             ctx,
             api_key: api_key_val,
             finch_name: finch_name,
             max_tokens: max_tokens,
             provider_options: provider_options,
             receive_timeout: receive_timeout
           ) do
        {:ok, stream_resp} ->
          # Stream tokens to UI (and persisted vertex content) as they arrive.
          # We accumulate the *full* response text in the worker to ensure
          # we can safely overwrite the node content (bullet-proofing against
          # lost partial updates or GraphManager restarts).
          flush_started_at = System.monotonic_time(:millisecond)

          {final_full_text, final_buf, _, _last_flush_at, stream_updates} =
            Enum.reduce(
              ReqLLM.StreamResponse.tokens(stream_resp),
              {"", "", false, flush_started_at, 0},
              fn token, {full_text, buf, ttft_logged?, last_flush_at, stream_updates} ->
                chunk =
                  case token do
                    t when is_binary(t) -> t
                    t when is_list(t) -> IO.iodata_to_binary(t)
                    t -> to_string(t)
                  end

                ttft_logged? =
                  if not ttft_logged? and byte_size(chunk) > 0 do
                    ttft_duration = elapsed_duration(request_started_at)
                    emit_time_to_first_token(ttft_duration, provider_mod.id())
                    ttft_ms = duration_in_milliseconds(ttft_duration)
                    Logger.info("[LLMWorker] job_id=#{job_id} TTFT=#{ttft_ms}ms")
                    true
                  else
                    ttft_logged?
                  end

                new_full_text = full_text <> chunk
                new_buf = buf <> chunk
                now = System.monotonic_time(:millisecond)
                elapsed_ms = now - last_flush_at

                if should_flush_stream?(full_text == "", byte_size(new_buf), elapsed_ms) do
                  Utils.set_node_content(graph, to_node, new_full_text, live_view_topic)
                  {new_full_text, "", ttft_logged?, now, stream_updates + 1}
                else
                  {new_full_text, new_buf, ttft_logged?, last_flush_at, stream_updates}
                end
              end
            )

          stream_updates =
            if final_buf != "" do
              Utils.set_node_content(graph, to_node, final_full_text, live_view_topic)
              stream_updates + 1
            else
              stream_updates
            end

          {final_full_text, stream_updates} =
            case sanitize_response(final_full_text) do
              ^final_full_text ->
                {final_full_text, stream_updates}

              sanitized_text ->
                Logger.warning(
                  "[LLMWorker] job_id=#{job_id} removed forbidden fenced content from the completed response"
                )

                Utils.set_node_content(graph, to_node, sanitized_text, live_view_topic)
                {sanitized_text, stream_updates + 1}
            end

          finish_reason = ReqLLM.StreamResponse.finish_reason(stream_resp)

          cond do
            byte_size(final_full_text) == 0 ->
              Logger.warning(
                "#{provider_label(provider_mod)} stream yielded no tokens; will retry (empty_stream)"
              )

              {:error, :empty_stream}

            finish_reason == :content_filter ->
              Logger.warning(
                "[LLMWorker] job_id=#{job_id} stopped by content filter bytes=#{byte_size(final_full_text)} updates=#{stream_updates}"
              )

              persist_stream_error(
                graph,
                to_node,
                live_view_topic,
                "We stopped this response because its safety filter was triggered. Try rephrasing the question."
              )

              {:discard, :content_filter}

            incomplete_finish?(finish_reason) ->
              Logger.warning(
                "[LLMWorker] job_id=#{job_id} stopped before completion finish_reason=#{inspect(finish_reason)} bytes=#{byte_size(final_full_text)} updates=#{stream_updates}"
              )

              {:error, {:incomplete_stream, finish_reason}}

            missing_required_follow_ups?(instruction, final_full_text) ->
              final_full_text = append_fallback_follow_ups(final_full_text, instruction)
              Utils.set_node_content(graph, to_node, final_full_text, live_view_topic)

              total_ms =
                job_started_at
                |> elapsed_duration()
                |> duration_in_milliseconds()

              stream_updates = stream_updates + 1

              Logger.warning(
                "[LLMWorker] job_id=#{job_id} completed without required follow-ups; appended fallback follow-up questions total=#{total_ms}ms bytes=#{byte_size(final_full_text)} updates=#{stream_updates} finish_reason=#{inspect(finish_reason)}"
              )

              finalize(graph, to_node, live_view_topic)
              :ok

            true ->
              total_ms =
                job_started_at
                |> elapsed_duration()
                |> duration_in_milliseconds()

              Logger.info(
                "[LLMWorker] job_id=#{job_id} completed total=#{total_ms}ms bytes=#{byte_size(final_full_text)} updates=#{stream_updates} finish_reason=#{inspect(finish_reason)}"
              )

              finalize(graph, to_node, live_view_topic)
              :ok
          end

        {:error, err} ->
          Logger.error("#{provider_label(provider_mod)} request error: #{inspect(err)}")
          {:error, err}
      end
    end
  end

  def skip_existing_response?(1, content) when is_binary(content), do: byte_size(content) > 50
  def skip_existing_response?(_attempt, _content), do: false

  @doc false
  def request_max_tokens(args, graph) do
    case Map.get(args, "max_tokens") do
      max_tokens when is_integer(max_tokens) and max_tokens > 0 ->
        max_tokens

      _other ->
        graph
        |> ModeServer.get_mode()
        |> PromptsStructured.max_output_tokens()
    end
  end

  @doc false
  def sanitize_response(text) when is_binary(text) do
    if String.contains?(text, "```") do
      text
      |> String.replace(~r/^[ \t]*```[^\n]*\n.*?^[ \t]*```[ \t]*$/ms, "")
      |> String.replace(~r/^[ \t]*```[^\n]*$/m, "")
      |> String.replace(~r/\n{3,}/, "\n\n")
      |> String.trim()
    else
      text
    end
  end

  def should_flush_stream?(first_chunk?, buffered_bytes, elapsed_ms) do
    first_chunk? or
      (buffered_bytes >= @buffer_size and elapsed_ms >= @stream_flush_min_interval_ms) or
      elapsed_ms >= @stream_flush_max_interval_ms
  end

  def queue_reference_time(attempt, _inserted_at, %DateTime{} = scheduled_at)
      when attempt > 1,
      do: scheduled_at

  def queue_reference_time(_attempt, inserted_at, _scheduled_at), do: inserted_at

  def queue_wait_duration(%DateTime{} = inserted_at, started_at_microsecond)
      when is_integer(started_at_microsecond) do
    wait_microseconds =
      max(started_at_microsecond - DateTime.to_unix(inserted_at, :microsecond), 0)

    System.convert_time_unit(wait_microseconds, :microsecond, :native)
  end

  def queue_wait_duration(_inserted_at, _started_at_microsecond), do: nil

  def emit_time_to_first_token(duration, provider)
      when is_integer(duration) and duration >= 0 do
    :telemetry.execute(
      @time_to_first_token_event,
      %{duration: duration},
      %{provider: provider, outcome: :success}
    )
  end

  def emit_queue_wait(duration, provider, outcome)
      when is_integer(duration) and duration >= 0 do
    :telemetry.execute(
      @queue_wait_event,
      %{duration: duration},
      %{provider: provider, outcome: outcome}
    )
  end

  def emit_job_duration(duration, provider, outcome)
      when is_integer(duration) and duration >= 0 do
    :telemetry.execute(
      @job_event,
      %{duration: duration},
      %{provider: provider, outcome: outcome}
    )
  end

  defp emit_completion_telemetry(job_started_at, provider, outcome) do
    emit_job_duration(elapsed_duration(job_started_at), provider, outcome)
  end

  defp elapsed_duration(started_at) do
    max(System.monotonic_time() - started_at, 0)
  end

  defp duration_in_milliseconds(duration) do
    System.convert_time_unit(duration, :native, :millisecond)
  end

  defp outcome_for_result(:ok), do: :success
  defp outcome_for_result({:discard, _reason}), do: :discard
  defp outcome_for_result({:error, _reason}), do: :error
  defp outcome_for_result(_result), do: :unknown

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

  defp terminal_error_message(_provider_mod, {:error, :empty_stream}) do
    "The model returned an empty response. Please try again."
  end

  defp terminal_error_message(provider_mod, {:error, {:incomplete_stream, reason}}) do
    "#{provider_label(provider_mod)} stopped before completing the response (#{reason}). Please try again."
  end

  defp terminal_error_message(_provider_mod, {:error, %Mint.TransportError{reason: reason}}) do
    "Network error while generating the response: #{inspect(reason)}"
  end

  defp terminal_error_message(provider_mod, {:error, reason}) do
    "#{provider_label(provider_mod)} request error: #{inspect(reason)}"
  end

  defp persist_stream_error(graph, to_node, live_view_topic, message) do
    GraphManager.set_node_content(graph, to_node, message)
    GraphManager.save_graph(graph)

    Phoenix.PubSub.broadcast(
      Dialectic.PubSub,
      live_view_topic,
      {:stream_error, message, :node_id, to_node}
    )

    Phoenix.PubSub.broadcast(
      Dialectic.PubSub,
      live_view_topic,
      {:llm_request_complete, to_node}
    )
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

  # Prefer arg "provider" (string), else env LLM_PROVIDER, else default to Gemini
  defp select_provider(%{"provider" => p}) when is_binary(p), do: provider_module_from_string(p)

  defp select_provider(_args) do
    case System.get_env("LLM_PROVIDER") do
      nil -> Dialectic.LLM.Providers.Google
      "" -> Dialectic.LLM.Providers.Google
      p when is_binary(p) -> provider_module_from_string(p)
    end
  end

  defp provider_module_from_string(p) when is_binary(p) do
    case String.downcase(String.trim(p)) do
      "google" -> Dialectic.LLM.Providers.Google
      "gemini" -> Dialectic.LLM.Providers.Google
      "openai" -> Dialectic.LLM.Providers.OpenAI
      # Fallback
      _ -> Dialectic.LLM.Providers.Google
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
