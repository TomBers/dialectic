defmodule Dialectic.Evaluation.StreamTimingTest do
  use ExUnit.Case, async: true
  alias Dialectic.Evaluation.StreamTiming

  test "distinguishes the first token from a readable passage and tracks later stalls" do
    timing =
      StreamTiming.new()
      |> StreamTiming.record("", 100)
      |> StreamTiming.record("# Title\n", 500)
      |> StreamTiming.record(String.duplicate("word ", 48), 1400)
      |> StreamTiming.record("More", 4200)

    assert StreamTiming.metrics(timing) == %{
             first_token_ms: 500,
             first_50_words_ms: 1400,
             longest_content_gap_ms: 2800
           }
  end

  test "partial words across chunks are counted as one word" do
    timing = StreamTiming.new() |> StreamTiming.record(String.duplicate("wor", 60), 500)
    assert timing.first_50_words_ms == nil
    assert StreamTiming.record(timing, "d ", 600).first_50_words_ms == nil
  end
end
