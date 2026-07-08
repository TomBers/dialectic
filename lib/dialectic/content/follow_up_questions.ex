defmodule Dialectic.Content.FollowUpQuestions do
  @moduledoc false

  @heading_regex ~r/^##\s+Follow-up questions\s*$/im
  @numbered_question_regex ~r/^\d+[\.)]\s+(.+\?)$/

  def extract(text) when is_binary(text) do
    case split_section(text) do
      {_before, body} ->
        lines =
          body
          |> String.split("\n")
          |> Enum.map(&String.trim/1)
          |> Enum.reject(&(&1 == ""))

        if length(lines) == 3 and Enum.all?(lines, &numbered_question_line?/1) do
          Enum.map(lines, &clean_numbered_question/1)
        else
          []
        end

      :not_found ->
        []
    end
  end

  def extract(_text), do: []

  def present?(text), do: extract(text) != []

  def strip_section(text) when is_binary(text) do
    case split_section(text) do
      {before, _body} -> String.trim_trailing(before)
      :not_found -> String.trim_trailing(text)
    end
  end

  def strip_section(_text), do: ""

  def append_section(text, questions) when is_list(questions) do
    numbered_questions =
      questions
      |> Enum.take(3)
      |> Enum.with_index(1)
      |> Enum.map(fn {question, index} -> "#{index}. #{String.trim(to_string(question))}" end)

    [String.trim_trailing(text), "## Follow-up questions" | numbered_questions]
    |> Enum.join("\n\n")
  end

  defp split_section(text) do
    case Regex.split(@heading_regex, text, parts: 2) do
      [before, body] -> {before, body}
      [_text] -> :not_found
    end
  end

  defp numbered_question_line?(line), do: Regex.match?(@numbered_question_regex, line)

  defp clean_numbered_question(line) do
    case Regex.run(@numbered_question_regex, line, capture: :all_but_first) do
      [question] -> String.trim(question)
      _ -> line
    end
  end
end
