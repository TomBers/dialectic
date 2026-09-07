defmodule Dialectic.Evaluation.AnswerBenchmarkTest do
  use ExUnit.Case, async: true
  alias Dialectic.Evaluation.AnswerBenchmark

  test "all twenty cases have unique IDs, review criteria and usable application prompts" do
    cases = AnswerBenchmark.cases()
    assert length(cases) == 20
    assert Enum.uniq_by(cases, & &1["id"]) == cases

    for test_case <- cases do
      assert length(test_case["rubric"]) >= 2
      assert is_binary(AnswerBenchmark.instruction(test_case))
    end
  end

  test "links and length cannot produce an accuracy grade" do
    test_case = Enum.find(AnswerBenchmark.cases(), &(&1["id"] == "hbs-retrieval"))

    result =
      AnswerBenchmark.assess(test_case, "An incorrect but cited claim", %{
        google: %{groundingChunks: [%{web: %{uri: "https://example.org"}}]}
      })

    assert result.expected_source_links_returned
    assert result.review == nil
    assert result.within_word_range == false
    assert result.rubric == test_case["rubric"]

    assert AnswerBenchmark.assess(test_case, "A claim", nil).expected_source_links_returned ==
             false
  end

  test "invalid learning plans are explicitly flagged" do
    test_case = Enum.find(AnswerBenchmark.cases(), &(&1["id"] == "learning-plan"))
    result = AnswerBenchmark.assess(test_case, "# Just an essay", nil)
    assert result.plan_format_valid == false
    assert result.within_word_range == nil
    assert result.review == nil
  end

  test "buffered plans include the discarded attempt in the visible wait" do
    first = %{
      status: "completed",
      plan_format_valid: false,
      total_ms: 4000,
      first_token_ms: 500,
      first_50_words_ms: 900,
      output: "Invalid plan"
    }

    repaired = %{
      status: "completed",
      plan_format_valid: true,
      total_ms: 3000,
      first_token_ms: 400,
      output: "Valid plan"
    }

    result = AnswerBenchmark.summarize_attempts(%{"kind" => "plan"}, repaired, [first, repaired])
    assert result.first_token_ms == 500
    assert result.first_50_words_ms == 900
    assert result.estimated_first_visible_ms == 7000
    assert result.total_ms == 7000
    assert result.repair_count == 1
    assert result.request_count == 2
  end

  test "a rejected plan has no visible-answer time; streaming answers use first content" do
    invalid = %{
      status: "completed",
      plan_format_valid: false,
      total_ms: 3000,
      first_token_ms: 500
    }

    result = AnswerBenchmark.summarize_attempts(%{"kind" => "plan"}, invalid, [invalid])
    assert result.status == "invalid_plan"
    assert result.estimated_first_visible_ms == nil
    answer = AnswerBenchmark.summarize_attempts(%{"kind" => "answer"}, invalid, [invalid])
    assert answer.status == "completed"
    assert answer.estimated_first_visible_ms == 500
  end
end
