defmodule Dialectic.Responses.PrintPromptsTest do
  use ExUnit.Case, async: false

  @moduledoc """
  Console-printing test for visually inspecting all LLM prompts (with style preamble).

  Run:
    mix test test/dialectic/responses/print_prompts_test.exs

  Notes:
  - This test prints to the actual console by writing to the `:user` device,
    bypassing ExUnit's IO capture.
  - No assertions are made; it simply outputs each prompt variant.
  """

  alias Dialectic.Responses.Prompts

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

  test "print all prompt variants with style preamble" do
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
      Prompts.explain(context_a, topic)
      |> Prompts.wrap_with_style()

    sel_default =
      Prompts.selection(context_a, selection_text)
      |> Prompts.wrap_with_style()

    sel_custom =
      Prompts.selection(context_a, selection_with_headings)
      |> Prompts.wrap_with_style()

    synth =
      Prompts.synthesis(context_a, context_b, pos1, pos2)
      |> Prompts.wrap_with_style()

    thesis =
      Prompts.thesis(
        context_a,
        "Stochastic policies tend to generalize better in high-variance environments"
      )
      |> Prompts.wrap_with_style()

    antithesis =
      Prompts.antithesis(
        context_a,
        "Off-policy methods are always superior to on-policy approaches"
      )
      |> Prompts.wrap_with_style()

    related =
      Prompts.related_ideas(context_a, "Temporal difference learning")
      |> Prompts.wrap_with_style()

    deep =
      Prompts.deep_dive(context_a, "Policy gradient theorem")
      |> Prompts.wrap_with_style()

    say("\nLLM Prompt Catalog (with style preamble)")

    print_prompt("Explain", explain)
    print_prompt("Selection (default schema applied)", sel_default)
    print_prompt("Selection (custom headings provided)", sel_custom)
    print_prompt("Synthesis", synth)
    print_prompt("Thesis", thesis)
    print_prompt("Antithesis", antithesis)
    print_prompt("Related ideas", related)
    print_prompt("Deep dive", deep)

    :ok
  end
end
