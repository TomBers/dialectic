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

  test "blank chunks preserve word boundaries without recording visible content" do
    blank =
      StreamTiming.new()
      |> StreamTiming.record("\n", 100)
      |> StreamTiming.record(" \t\r\n", 200)

    assert StreamTiming.metrics(blank) == StreamTiming.metrics(StreamTiming.new())
    assert blank.previous_content_ms == nil

    first = StreamTiming.record(blank, "First", 500)
    separated = StreamTiming.record(first, " \n", 1500)

    assert StreamTiming.metrics(separated) == StreamTiming.metrics(first)
    assert separated.previous_content_ms == 500

    fifty = StreamTiming.record(separated, String.duplicate("word ", 49), 2500)

    assert StreamTiming.metrics(fifty) == %{
             first_token_ms: 500,
             first_50_words_ms: 2500,
             longest_content_gap_ms: 2000
           }

    assert StreamTiming.record(fifty, "\n\t ", 10_000) == fifty
  end
end
