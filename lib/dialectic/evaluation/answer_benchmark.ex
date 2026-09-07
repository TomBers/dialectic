defmodule Dialectic.Evaluation.AnswerBenchmark do
  @moduledoc false

  alias Dialectic.LLM.{Grounding, Provider}
  alias Dialectic.LLM.Providers.Google
  alias Dialectic.Responses.{GuidedLearningPlan, Prompts, PromptsStructured}
  alias Dialectic.Evaluation.StreamTiming

  def cases do
    :dialectic
    |> :code.priv_dir()
    |> Path.join("evaluation/learning_cases.json")
    |> File.read!()
    |> Jason.decode!()
  end

  def run(opts \\ []) do
    model = Keyword.get(opts, :model, Google.model())
    concurrency = Keyword.get(opts, :concurrency, 2)
    unless concurrency in 1..4, do: raise(ArgumentError, "concurrency must be between 1 and 4")
    selected = select_cases(opts)
    thinking = Keyword.get(opts, :thinking)

    unless thinking in [nil, "minimal", "low", "medium", "high"],
      do: raise(ArgumentError, "invalid thinking level")

    {:ok, api_key} = Provider.api_key(Google)

    results =
      selected
      |> Task.async_stream(
        fn test_case -> generate_with_repair(test_case, model, api_key, opts) end,
        max_concurrency: concurrency,
        timeout: 240_000,
        on_timeout: :kill_task,
        ordered: true
      )
      |> Enum.zip(selected)
      |> Enum.map(fn
        {{:ok, result}, _case} ->
          result

        {{:exit, _reason}, test_case} ->
          %{
            id: test_case["id"],
            status: "error",
            error: "request timed out or exited",
            review: nil
          }
      end)

    %{
      version: 2,
      generated_at: DateTime.utc_now(),
      provider: "google",
      model: model,
      thinking: thinking || "application depth defaults",
      concurrency: concurrency,
      cost_basis:
        "Usage costs are SDK estimates, not billing totals; search fees or other charges may be absent.",
      scope:
        "Provider streaming with application prompts, search settings and one learning-plan format repair. First-visible estimates account for buffered plans; queue, browser rendering and transport retries require separate live measurements.",
      review_scale: %{
        0 => "incorrect or harmful to understanding",
        1 => "material weaknesses",
        2 => "useful with minor weaknesses",
        3 => "accurate and useful"
      },
      review_dimensions: ["accuracy", "source_support", "uncertainty", "learning_usefulness"],
      results: results
    }
  end

  def assess(test_case, text, grounding) do
    profile = PromptsStructured.response_profile(mode(test_case["mode"]))

    body =
      text
      |> String.split(~r/^##\s+(?:Follow.?up|(?:Suggested\s+)?Further|Questions)/im, parts: 2)
      |> hd()

    words = length(String.split(body))
    initial? = test_case["kind"] == "initial"
    min_words = if initial?, do: profile.initial_min_words, else: profile.min_words
    max_words = if initial?, do: profile.initial_max_words, else: profile.max_words
    sources = Grounding.sources(grounding)

    %{
      body_words: words,
      total_words: length(String.split(text)),
      suggested_word_range: [min_words, max_words],
      within_word_range:
        if(test_case["kind"] == "plan", do: nil, else: words in min_words..max_words),
      source_links: sources,
      expected_source_links_returned:
        if(test_case["source_links_expected"], do: sources != [], else: nil),
      plan_format_valid:
        if(test_case["kind"] == "plan",
          do: match?({:ok, _}, GuidedLearningPlan.validate(text)),
          else: nil
        ),
      review: nil,
      rubric: test_case["rubric"],
      reference_sources: test_case["references"]
    }
  end

  def instruction(test_case) do
    context = test_case["context"] || ""
    question = test_case["question"]

    case test_case["kind"] do
      "initial" ->
        Prompts.initial_explainer(context, question, mode(test_case["mode"]))

      "source_check" ->
        Prompts.says_who(context, question)

      "plan" ->
        Prompts.guided_learning_plan(context, question, %{
          title: "Prior answer about AI-assisted study",
          content: context
        })

      "answer" ->
        Prompts.explain(context, question)
    end
  end

  defp generate_with_repair(test_case, model, api_key, opts) do
    first = generate(test_case, model, api_key, opts)

    {result, attempts} =
      if test_case["kind"] == "plan" and Map.get(first, :status) == "completed" and
           first.plan_format_valid == false do
        {:error, errors} = GuidedLearningPlan.validate(first.output)
        repair = GuidedLearningPlan.repair_prompt(instruction(test_case), first.output, errors)
        repaired = generate(test_case, model, api_key, Keyword.put(opts, :instruction, repair))
        {Map.put(repaired, :initial_plan_errors, errors), [first, repaired]}
      else
        {first, [first]}
      end

    summarize_attempts(test_case, result, attempts)
  end

  def summarize_attempts(test_case, result, [first | _] = attempts) do
    total_ms = Enum.sum(Enum.map(attempts, &Map.get(&1, :total_ms, 0)))

    valid? =
      Map.get(result, :status) == "completed" and
        (test_case["kind"] != "plan" or Map.get(result, :plan_format_valid) == true)

    status =
      if Map.get(result, :status) == "completed" and !valid?,
        do: "invalid_plan",
        else: result.status

    Map.merge(result, %{
      status: status,
      total_ms: total_ms,
      request_count: length(attempts),
      repair_count: length(attempts) - 1,
      first_token_ms: Map.get(first, :first_token_ms),
      first_50_words_ms: Map.get(first, :first_50_words_ms),
      longest_content_gap_ms:
        Enum.max(Enum.map(attempts, &Map.get(&1, :longest_content_gap_ms, 0))),
      estimated_first_visible_ms:
        if(test_case["kind"] == "plan",
          do: if(valid?, do: total_ms),
          else: Map.get(first, :first_token_ms)
        ),
      attempts:
        Enum.map(
          attempts,
          &Map.take(&1, [
            :status,
            :total_ms,
            :first_token_ms,
            :first_50_words_ms,
            :longest_content_gap_ms,
            :output,
            :usage,
            :plan_format_valid,
            :error
          ])
        )
    })
  end

  defp generate(test_case, model, api_key, opts) do
    mode = mode(test_case["mode"])
    system = PromptsStructured.system_preamble(mode)
    instruction = Keyword.get_lazy(opts, :instruction, fn -> instruction(test_case) end)

    context =
      ReqLLM.Context.new([ReqLLM.Context.system(system), ReqLLM.Context.user(instruction)])

    start = System.monotonic_time(:millisecond)

    options = [
      api_key: api_key,
      finch_name: Provider.finch_name(Google),
      max_tokens: PromptsStructured.max_output_tokens(mode),
      provider_options: provider_options(mode, opts),
      receive_timeout: 90_000
    ]

    model_spec =
      if model == Google.model(),
        do: {:google, [model: model]},
        else: %{provider: :google, id: model}

    case ReqLLM.stream_text(model_spec, context, options) do
      {:ok, response} ->
        {chunks, timing, grounding} =
          Enum.reduce(response.stream, {[], StreamTiming.new(), nil}, fn
            %ReqLLM.StreamChunk{type: :content, text: text}, {chunks, timing, grounding}
            when is_binary(text) and text != "" ->
              {[text | chunks], StreamTiming.record(timing, text, elapsed(start)), grounding}

            %ReqLLM.StreamChunk{type: :meta, metadata: metadata}, {chunks, first, grounding} ->
              {chunks, first, Grounding.merge(grounding, metadata)}

            _chunk, acc ->
              acc
          end)

        text = chunks |> Enum.reverse() |> IO.iodata_to_binary()
        finish_reason = ReqLLM.StreamResponse.finish_reason(response)
        usage = ReqLLM.StreamResponse.usage(response)

        assess(test_case, Grounding.strip_sources(text), grounding)
        |> Map.merge(StreamTiming.metrics(timing))
        |> Map.merge(%{
          id: test_case["id"],
          mode: test_case["mode"],
          thinking: Keyword.fetch!(provider_options(mode, opts), :google_thinking_level),
          question: test_case["question"],
          status:
            if(String.trim(text) == "" or finish_reason not in [:stop, :tool_calls, "stop"],
              do: "incomplete",
              else: "completed"
            ),
          total_ms: elapsed(start),
          usage: usage,
          finish_reason: finish_reason,
          output: text,
          grounding_metadata: grounding,
          prompt_hash:
            :crypto.hash(:sha256, system <> "\n" <> instruction) |> Base.encode16(case: :lower)
        })

      {:error, error} ->
        %{
          id: test_case["id"],
          status: "error",
          error: error_type(error),
          total_ms: elapsed(start),
          review: nil
        }
    end
  rescue
    error -> %{id: test_case["id"], status: "error", error: error_type(error), review: nil}
  end

  defp provider_options(mode, opts) do
    case Keyword.get(opts, :thinking) do
      nil -> Google.provider_options(mode)
      thinking -> Keyword.put(Google.provider_options(mode), :google_thinking_level, thinking)
    end
  end

  defp select_cases(opts) do
    selected =
      case Keyword.get(opts, :case) do
        nil -> cases()
        id -> Enum.filter(cases(), &(&1["id"] == id))
      end

    if selected == [], do: raise(ArgumentError, "unknown benchmark case")

    case Keyword.get(opts, :limit) do
      nil -> selected
      limit when is_integer(limit) and limit > 0 -> Enum.take(selected, limit)
      _ -> raise ArgumentError, "limit must be a positive integer"
    end
  end

  defp mode("simple"), do: :high_school
  defp mode("expanded"), do: :university
  defp mode("expert"), do: :expert
  defp elapsed(start), do: System.monotonic_time(:millisecond) - start
  defp error_type(%{__struct__: module}), do: inspect(module)
  defp error_type(_error), do: "provider request failed"
end
