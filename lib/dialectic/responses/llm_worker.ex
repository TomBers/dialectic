defmodule Dialectic.Workers.LLMWorker do
  @moduledoc """
  Provider-agnostic LLM worker built on ReqLLM.

  This worker centralizes the streaming logic and delegates all provider-specific
  concerns (API key, model, provider_options, timeouts) to modules that implement
  the `Dialectic.LLM.Provider` behaviour. This allows you to plug in providers
  like OpenAI or Google (Gemini) without changing the streaming pipeline.


  Expected job args:
    - "question" (string)
    - "to_node" (node id)
    - "graph" (graph id)
    - "live_view_topic" (PubSub topic for the LiveView)

  Notes:
    - This module is designed to replace the previous OpenAI-specific worker.
    - Uses a generic queue name (`:llm_request`) shared by all providers.
  """

  # Use a generic LLM queue shared by all providers.
  use Oban.Worker, queue: :llm_request, max_attempts: 5, priority: 0

  require Logger

  alias Dialectic.LLM.Grounding
  alias Dialectic.Responses.Utils
  alias Dialectic.Responses.{GuidedLearningPlan, ModeServer, PromptsStructured}

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

  def backoff(%Oban.Job{
        attempt: attempt,
        unsaved_error: %{
          reason: %ReqLLM.Error.API.Request{
            status: status,
            provider_code: provider_code,
            retryable: true
          }
        }
      })
      when status in [429, 502, 503, 504] or provider_code in [429, 502, 503, 504],
      do: provider_retry_delay(attempt)

  def backoff(job), do: Oban.Worker.backoff(job)

  @doc false
  def provider_retry_delay(1), do: 3
  def provider_retry_delay(_attempt), do: 10

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
    provider_mod = Dialectic.LLM.Providers.Google
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
        if attempt >= max_attempts do
          cleanup_terminal_guided_submission(args, graph, to_node)
        end

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
      if attempt == 1 do
        GraphManager.update_vertex_fields(graph, to_node, %{
          content: "",
          guided_plan: nil,
          grounding_metadata: nil
        })
      end

      result =
        do_llm_request(
          job_id,
          job_started_at,
          attempt,
          args,
          graph,
          to_node,
          live_view_topic,
          provider_mod
        )

      cond do
        attempt >= max_attempts and match?({:error, _reason}, result) ->
          persist_stream_error(
            graph,
            to_node,
            live_view_topic,
            terminal_error_message(provider_mod, result)
          )

        retryable_provider_overload?(result) ->
          persist_retry_status(
            graph,
            to_node,
            live_view_topic,
            provider_retry_message(provider_mod, attempt, max_attempts)
          )

        true ->
          :ok
      end

      if terminal_failure?(result, attempt, max_attempts) do
        cleanup_terminal_guided_submission(args, graph, to_node)
      end

      {result, outcome_for_result(result)}
    end
  end

  # Extracted LLM request logic to separate function for clarity
  defp do_llm_request(
         job_id,
         job_started_at,
         attempt,
         args,
         graph,
         to_node,
         live_view_topic,
         provider_mod
       ) do
    question = Map.get(args, "question", "")
    buffer_response? = guided_learning_plan_contract?(args)

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
      model_spec = request_model_spec(provider_mod, attempt)

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
      provider_options = provider_options(provider_mod, Map.get(args, "response_level"))
      max_tokens = request_max_tokens(args, graph)

      request_options = [
        api_key: api_key_val,
        finch_name: finch_name,
        max_tokens: max_tokens,
        provider_options: provider_options,
        receive_timeout: receive_timeout
      ]

      thinking_level = Keyword.get(provider_options, :google_thinking_level, "default")

      grounding? =
        case Keyword.get(provider_options, :google_grounding) do
          %{enable: enabled?} -> enabled?
          _other -> false
        end

      Logger.info(
        "[LLMWorker] job_id=#{job_id} response_level=#{Map.get(args, "response_level", "unknown")} max_tokens=#{max_tokens} thinking_level=#{thinking_level} grounding=#{grounding?}"
      )

      request_started_at = System.monotonic_time()

      case ReqLLM.stream_text(model_spec, ctx, request_options) do
        {:ok, stream_resp} ->
          # Stream tokens to UI (and persisted vertex content) as they arrive.
          # We accumulate the *full* response text in the worker to ensure
          # we can safely overwrite the node content (bullet-proofing against
          # lost partial updates or GraphManager restarts).
          flush_started_at = System.monotonic_time(:millisecond)

          {final_chunks, _final_size, final_buffer_size, _, _last_flush_at, stream_updates,
           grounding_metadata} =
            Enum.reduce(
              stream_resp.stream,
              {[], 0, 0, false, flush_started_at, 0, nil},
              fn
                %ReqLLM.StreamChunk{type: :content, text: token},
                {chunks, full_size, buffer_size, ttft_logged?, last_flush_at, stream_updates,
                 grounding_metadata} ->
                  chunk =
                    case token do
                      t when is_binary(t) -> t
                      t when is_list(t) -> IO.iodata_to_binary(t)
                      t -> to_string(t || "")
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

                  chunk_size = byte_size(chunk)
                  new_chunks = [chunk | chunks]
                  new_full_size = full_size + chunk_size
                  new_buffer_size = buffer_size + chunk_size
                  now = System.monotonic_time(:millisecond)
                  elapsed_ms = now - last_flush_at

                  if should_flush_stream?(full_size == 0, new_buffer_size, elapsed_ms) do
                    if buffer_response? do
                      {new_chunks, new_full_size, 0, ttft_logged?, now, stream_updates,
                       grounding_metadata}
                    else
                      full_text = new_chunks |> Enum.reverse() |> IO.iodata_to_binary()
                      Utils.set_node_content(graph, to_node, full_text, live_view_topic)

                      {new_chunks, new_full_size, 0, ttft_logged?, now, stream_updates + 1,
                       grounding_metadata}
                    end
                  else
                    {new_chunks, new_full_size, new_buffer_size, ttft_logged?, last_flush_at,
                     stream_updates, grounding_metadata}
                  end

                %ReqLLM.StreamChunk{type: :meta, metadata: metadata},
                {chunks, full_size, buffer_size, ttft_logged?, last_flush_at, stream_updates,
                 grounding_metadata} ->
                  grounding_metadata = Grounding.merge(grounding_metadata, metadata)

                  {chunks, full_size, buffer_size, ttft_logged?, last_flush_at, stream_updates,
                   grounding_metadata}

                _chunk, state ->
                  state
              end
            )

          final_full_text = final_chunks |> Enum.reverse() |> IO.iodata_to_binary()

          stream_updates =
            if final_buffer_size > 0 do
              if buffer_response? do
                stream_updates
              else
                Utils.set_node_content(graph, to_node, final_full_text, live_view_topic)
                stream_updates + 1
              end
            else
              stream_updates
            end

          {final_full_text, stream_updates} =
            if grounding? do
              cleaned_text = Grounding.strip_sources(final_full_text)

              unless buffer_response? do
                Utils.set_node_response(
                  graph,
                  to_node,
                  cleaned_text,
                  grounding_metadata,
                  live_view_topic
                )
              end

              {cleaned_text, if(buffer_response?, do: stream_updates, else: stream_updates + 1)}
            else
              {final_full_text, stream_updates}
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

            buffer_response? ->
              handle_guided_learning_plan_response(
                job_id,
                job_started_at,
                attempt,
                args,
                final_full_text,
                grounding_metadata,
                graph,
                to_node,
                live_view_topic,
                provider_mod,
                finish_reason
              )

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

  defp handle_guided_learning_plan_response(
         job_id,
         job_started_at,
         attempt,
         args,
         response,
         grounding_metadata,
         graph,
         to_node,
         live_view_topic,
         provider_mod,
         finish_reason
       ) do
    case guided_learning_plan_response_action(args, response) do
      {:accept, plan} ->
        {:ok, canonical_content} = GuidedLearningPlan.render(plan)
        GraphManager.update_vertex_fields(graph, to_node, %{guided_plan: plan})

        if is_nil(grounding_metadata) do
          Utils.set_node_content(graph, to_node, canonical_content, live_view_topic)
        else
          Utils.set_node_response(
            graph,
            to_node,
            canonical_content,
            grounding_metadata,
            live_view_topic
          )
        end

        total_ms =
          job_started_at
          |> elapsed_duration()
          |> duration_in_milliseconds()

        Logger.info(
          "[LLMWorker] job_id=#{job_id} completed validated guided learning plan total=#{total_ms}ms bytes=#{byte_size(canonical_content)} finish_reason=#{inspect(finish_reason)}"
        )

        finalize(graph, to_node, live_view_topic)
        :ok

      {:reject, errors} ->
        Logger.error(
          "[LLMWorker] job_id=#{job_id} guided learning plan failed validation after repair: #{inspect(errors)}"
        )

        persist_stream_error(
          graph,
          to_node,
          live_view_topic,
          "We couldn't create a valid learning plan. Please try again."
        )

        {:discard, :invalid_guided_learning_plan}

      {:repair, repair_instruction, errors} ->
        Logger.warning(
          "[LLMWorker] job_id=#{job_id} guided learning plan failed validation; attempting one repair: #{inspect(errors)}"
        )

        repair_args =
          args
          |> Map.put("instruction", repair_instruction)
          |> Map.put("guided_plan_repair_attempt", true)

        GraphManager.update_vertex_fields(graph, to_node, %{
          content: "",
          guided_plan: nil,
          grounding_metadata: nil
        })

        do_llm_request(
          job_id,
          job_started_at,
          attempt,
          repair_args,
          graph,
          to_node,
          live_view_topic,
          provider_mod
        )
    end
  end

  @doc false
  def guided_learning_plan_response_action(args, response) do
    case GuidedLearningPlan.validate(response) do
      {:ok, plan} ->
        {:accept, plan}

      {:error, errors} ->
        if Map.get(args, "guided_plan_repair_attempt", false) do
          {:reject, errors}
        else
          original_instruction = Map.get(args, "instruction", Map.get(args, "question", ""))

          repair_instruction =
            GuidedLearningPlan.repair_prompt(original_instruction, response, errors)

          {:repair, repair_instruction, errors}
        end
    end
  end

  defp guided_learning_plan_contract?(args) do
    Map.get(args, "response_contract") == "guided_learning_plan"
  end

  def skip_existing_response?(1, content) when is_binary(content), do: byte_size(content) > 50
  def skip_existing_response?(_attempt, _content), do: false

  defp provider_options(provider_mod, response_level) do
    mode =
      case response_level do
        "simple" -> :high_school
        "high_school" -> :high_school
        "expert" -> :expert
        _other -> :university
      end

    if function_exported?(provider_mod, :provider_options, 1) do
      provider_mod.provider_options(mode)
    else
      provider_mod.provider_options()
    end
  end

  @doc false
  def request_model_spec(_provider_mod, attempt) when attempt >= 3 do
    {:google, model: "gemini-3.1-flash-lite"}
  end

  def request_model_spec(provider_mod, _attempt),
    do: Dialectic.LLM.Provider.model_spec(provider_mod)

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

  defp terminal_failure?({:discard, _reason}, _attempt, _max_attempts), do: true
  defp terminal_failure?({:error, _reason}, attempt, max_attempts), do: attempt >= max_attempts
  defp terminal_failure?(_result, _attempt, _max_attempts), do: false

  defp cleanup_terminal_guided_submission(args, graph, to_node) do
    case Map.get(args, "guided_submission") do
      %{} = metadata -> GraphManager.cleanup_guided_submission(graph, to_node, metadata)
      _no_guided_submission -> :ok
    end
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

    [first_question, second_question, third_question] = [
      "What historical context most changes how we should understand #{topic}?",
      "Which interpretation of #{topic} is most contested, and why?",
      "What detail about #{topic} would be most rewarding to explore next?"
    ]

    [
      String.trim_trailing(text),
      "## Follow-up questions",
      "1. #{first_question}",
      "2. #{second_question}",
      "3. #{third_question}"
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
    if provider_overload_error?(reason) do
      "The AI service is still temporarily overloaded. Please try again in a moment."
    else
      "#{provider_label(provider_mod)} request error: #{inspect(reason)}"
    end
  end

  defp provider_retry_message(_provider_mod, attempt, max_attempts) do
    delay = provider_retry_delay(attempt)

    "The AI service is temporarily overloaded. Retrying in #{delay} seconds (attempt #{attempt + 1} of #{max_attempts})…"
  end

  defp retryable_provider_overload?({:error, reason}), do: provider_overload_error?(reason)
  defp retryable_provider_overload?(_result), do: false

  @doc false
  def provider_overload_error?(%ReqLLM.Error.API.Request{
        status: status,
        retryable: true
      })
      when status in [429, 502, 503, 504],
      do: true

  def provider_overload_error?(%ReqLLM.Error.API.Request{
        provider_code: provider_code,
        retryable: true
      })
      when provider_code in [429, 502, 503, 504],
      do: true

  def provider_overload_error?(_reason), do: false

  defp persist_retry_status(graph, to_node, live_view_topic, message) do
    GraphManager.set_node_content(graph, to_node, message)
    GraphManager.save_graph(graph)

    Phoenix.PubSub.broadcast(
      Dialectic.PubSub,
      live_view_topic,
      {:llm_request_retrying, message, :node_id, to_node}
    )
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

  defp provider_label(_mod), do: "Google"
end
