defmodule Dialectic.Evaluation.StreamTiming do
  @moduledoc false

  def new do
    %{
      first_token_ms: nil,
      first_50_words_ms: nil,
      longest_content_gap_ms: 0,
      previous_content_ms: nil,
      prefix: ""
    }
  end

  def record(timing, text, elapsed_ms) when is_binary(text) and text != "" do
    prefix = if timing.first_50_words_ms, do: "", else: timing.prefix <> text

    if String.trim(text) == "" do
      %{timing | prefix: prefix}
    else
      fifty_words_ms =
        timing.first_50_words_ms || if(length(String.split(prefix)) >= 50, do: elapsed_ms)

      gap = if timing.previous_content_ms, do: elapsed_ms - timing.previous_content_ms, else: 0

      %{
        timing
        | first_token_ms: timing.first_token_ms || elapsed_ms,
          first_50_words_ms: fifty_words_ms,
          longest_content_gap_ms: max(timing.longest_content_gap_ms, gap),
          previous_content_ms: elapsed_ms,
          prefix: if(fifty_words_ms, do: "", else: prefix)
      }
    end
  end

  def record(timing, _text, _elapsed_ms), do: timing

  def metrics(timing),
    do: Map.take(timing, [:first_token_ms, :first_50_words_ms, :longest_content_gap_ms])
end
