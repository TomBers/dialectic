defmodule Dialectic.Responses.PrintPromptsTest do
  use ExUnit.Case, async: false

  @moduledoc """
  Console-printing test for visually inspecting all LLM PromptsStructured.

  Run:
    mix test test/dialectic/responses/print_prompts_test.exs

  Notes:
  - This test prints to the actual console by writing to the `:user` device,
    bypassing ExUnit's IO capture.
  - No assertions are made; it simply outputs each prompt variant.
  """

  alias Dialectic.Responses.{PromptsStructured, PromptsCreative}

  defp io_device do
    # Ensure we bypass ExUnit's IO capture
    Process.whereis(:user) || :stdio
  end

  defp say(line), do: IO.puts(io_device(), line)

  defp section(title) do
    say("\n==============================")
    say(title)
    say("==============================\n")
  end

  defp print_prompt(title, prompt) do
    section(title)
    say(prompt)
  end

  test "print all prompt variants" do
    context_a = "Context A: prior notes, quotes, and references related to the current node."

    context_b =
      "Context B: alternative or contrasting references to synthesize against Context A."

    topic = "Reinforcement learning"

    selection_text =
      "Summarize the key claims and underlying assumptions for the current context."

    selection_with_headings = """
    Output (markdown):
    ## Custom Summary
    - Bullet 1
    - Bullet 2
    Return only the bullets above.
    """

    pos1 = "Exploration strategies in RL"
    pos2 = "Convergence guarantees for value-based methods"

    explain =
      PromptsStructured.explain(context_a, topic)

    sel_default =
      PromptsStructured.selection(context_a, selection_text)

    sel_custom =
      PromptsStructured.selection(context_a, selection_with_headings)

    synth =
      PromptsStructured.synthesis(context_a, context_b, pos1, pos2)

    thesis =
      PromptsStructured.thesis(
        context_a,
        "Stochastic policies tend to generalize better in high-variance environments"
      )

    antithesis =
      PromptsStructured.antithesis(
        context_a,
        "Off-policy methods are always superior to on-policy approaches"
      )

    related =
      PromptsStructured.related_ideas(context_a, "Temporal difference learning")

    deep =
      PromptsStructured.deep_dive(context_a, "Policy gradient theorem")

    say("\nLLM Prompt Catalog")

    print_prompt("Structured — Explain", explain)
    print_prompt("Creative — Explain", PromptsCreative.explain(context_a, topic))
    print_prompt("Structured — Selection (default schema applied)", sel_default)

    print_prompt(
      "Creative — Selection (default schema applied)",
      PromptsCreative.selection(context_a, selection_text)
    )

    print_prompt("Structured — Selection (custom headings provided)", sel_custom)

    print_prompt(
      "Creative — Selection (custom headings provided)",
      PromptsCreative.selection(context_a, selection_with_headings)
    )

    print_prompt("Structured — Synthesis", synth)

    print_prompt(
      "Creative — Synthesis",
      PromptsCreative.synthesis(context_a, context_b, pos1, pos2)
    )

    print_prompt("Structured — Thesis", thesis)

    print_prompt(
      "Creative — Thesis",
      PromptsCreative.thesis(
        context_a,
        "Stochastic policies tend to generalize better in high-variance environments"
      )
    )

    print_prompt("Structured — Antithesis", antithesis)

    print_prompt(
      "Creative — Antithesis",
      PromptsCreative.antithesis(
        context_a,
        "Off-policy methods are always superior to on-policy approaches"
      )
    )

    print_prompt("Structured — Related ideas", related)

    print_prompt(
      "Creative — Related ideas",
      PromptsCreative.related_ideas(context_a, "Temporal difference learning")
    )

    print_prompt("Structured — Deep dive", deep)

    print_prompt(
      "Creative — Deep dive",
      PromptsCreative.deep_dive(context_a, "Policy gradient theorem")
    )

    :ok
  end
end
