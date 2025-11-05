defmodule Dialectic.Responses.PromptBuilderPrintTest do
  use ExUnit.Case, async: true

  @moduletag :skip
  @moduletag :integration

  @doc """
  Prints all PromptBuilder prompts (final composed prompts) for both active modes.

  Why this test is skipped by default:
  - It is meant as a developer aid to visually inspect prompt wording and formatting.
  - It produces a lot of console output.

  How to run it:
      mix test test/dialectic/responses/prompt_builder_print_test.exs --color --include skip

  Notes:
  - This test uses the pure PromptBuilder module and does not depend on GraphManager or any background jobs.
  - You can customize the inputs below as needed to iterate on different content quickly.
  """
  test "print all prompts for PromptBuilder across both modes" do
    modes = Dialectic.Responses.Modes.order()

    request = "How do CRDTs work and when should I prefer them?"
    selection = "Rewrite the highlighted passage more clearly with one concrete example."
    a = "Type systems prevent runtime errors"
    b = "Dynamic typing increases flexibility"
    thesis = "Functional programming improves testability"
    antithesis = "Microservices are always better than monoliths"
    ideas_title = "Event Sourcing in Distributed Systems"
    deepdive_topic = "Bayes' theorem"

    bodies = [
      {"Response", Dialectic.Responses.PromptBuilder.question_response(request)},
      {"Selection", Dialectic.Responses.PromptBuilder.question_selection(selection)},
      {"Synthesis", Dialectic.Responses.PromptBuilder.question_synthesis(a, b)},
      {"Thesis", Dialectic.Responses.PromptBuilder.question_thesis(thesis)},
      {"Antithesis", Dialectic.Responses.PromptBuilder.question_antithesis(antithesis)},
      {"Related ideas", Dialectic.Responses.PromptBuilder.question_related_ideas(ideas_title)},
      {"Deepdive", Dialectic.Responses.PromptBuilder.question_deepdive(deepdive_topic)}
    ]

    sep = String.duplicate("=", 80)
    section_sep = String.duplicate("-", 80)
    sub_sep = String.duplicate("~", 80)

    Enum.each(modes, fn mode ->
      mode_info = Dialectic.Responses.Modes.fetch(mode)
      mode_label = Map.get(mode_info, :label, to_string(mode))

      IO.puts("\n" <> sep)
      IO.puts("Mode: #{mode_label} (#{mode})")
      IO.puts(section_sep)

      Enum.each(bodies, fn {label, body} ->
        IO.puts("\n" <> sub_sep)
        IO.puts(">>> " <> label)
        IO.puts(sub_sep)
        IO.puts(Dialectic.Responses.PromptBuilder.compose(body, mode))
      end)

      IO.puts(section_sep <> "\n")
    end)

    # This test is for console output only
    assert true
  end
end
