defmodule Dialectic.Responses.PromptBuilderTest do
  use ExUnit.Case, async: true

  alias Dialectic.Responses.PromptBuilder
  alias Dialectic.Responses.Modes

  defp normalize(str) do
    str
    |> to_string()
    |> String.split("\n")
    |> Enum.map(&String.trim_leading/1)
    |> Enum.join("\n")
    |> String.trim()
  end

  defp assert_same(a, b) do
    assert normalize(a) == normalize(b)
  end

  describe "compose/2 (pure final prompt assembly)" do
    test "prefixes the system prompt for each active mode" do
      # Modes.order/0 returns [:structured, :creative] with our current config
      for mode <- Modes.order() do
        question_body = """
        Instruction:
        Do the thing clearly and briefly.
        """

        expected = Modes.system_prompt(mode) <> "\n\n" <> question_body
        composed = PromptBuilder.compose(question_body, mode)

        assert composed == expected
        assert String.starts_with?(composed, Modes.base_style())
        assert String.contains?(composed, Modes.mode_prompt(mode))
        assert String.ends_with?(composed, question_body)
      end
    end
  end

  describe "question_response/1" do
    test "returns compact instruction to answer directly" do
      actual = PromptBuilder.question_response("Explain recursion")

      expected = """
      Instruction:
      Answer "Explain recursion" directly. Be clear and compact; use bullets only if they aid clarity.
      """

      assert_same(expected, actual)
    end
  end

  describe "question_selection/1" do
    test "returns instruction that paraphrases and explains relevance" do
      selection = "Rewrite the highlighted passage more clearly."
      actual = PromptBuilder.question_selection(selection)

      expected = """
      Instruction (apply to the selection below):
      Rewrite the highlighted passage more clearly.

      Instruction:
      Paraphrase the selection and explain its relevance to the current context. Be brief; use bullets only if they clarify key claims, assumptions, implications, or limitations.
      """

      assert_same(expected, actual)
    end
  end

  describe "question_synthesis/2" do
    test "compares two statements and proposes a synthesis or scope boundary" do
      a = "Type systems prevent runtime errors"
      b = "Dynamic typing increases flexibility"

      actual = PromptBuilder.question_synthesis(a, b)

      expected = """
      Instruction:
      Compare "Type systems prevent runtime errors" and "Dynamic typing increases flexibility": name common ground and key tensions; propose a synthesis or clear scope boundary. Keep it concise; use bullets only to highlight trade‑offs.
      """

      assert_same(expected, actual)
    end
  end

  describe "question_thesis/1" do
    test "makes a concise, rigorous case" do
      statement = "Functional programming improves testability"
      actual = PromptBuilder.question_thesis(statement)

      expected = """
      Instruction:
      Make a brief, rigorous case for "Functional programming improves testability": state the claim, give compact reasoning, and add one short example if useful.
      """

      assert_same(expected, actual)
    end
  end

  describe "question_antithesis/1" do
    test "provides a concise, rigorous critique" do
      statement = "Microservices are always better than monoliths"
      actual = PromptBuilder.question_antithesis(statement)

      expected = """
      Instruction:
      Give a brief, rigorous critique of "Microservices are always better than monoliths": steelman the opposing view, state the core objection, and support it with compact reasoning and, if helpful, a short counterexample.
      """

      assert_same(expected, actual)
    end
  end

  describe "question_related_ideas/1" do
    test "suggests diverse, related follow-up concepts as bullets" do
      title = "Event Sourcing in Distributed Systems"
      actual = PromptBuilder.question_related_ideas(title)

      expected = """
      Instruction:
      Suggest diverse, related concepts to explore next for "Event Sourcing in Distributed Systems". Return a concise bullet list; each bullet: concept — one‑sentence rationale or contrast.
      """

      assert_same(expected, actual)
    end
  end

  describe "question_deepdive/1" do
    test "explains rigorously for an advanced learner" do
      topic = "Bayes' theorem"
      actual = PromptBuilder.question_deepdive(topic)

      expected = """
      Instruction:
      Explain "Bayes' theorem" rigorously for an advanced learner: note assumptions and scope. Use 2–4 compact paragraphs; add brief caveats only if they clarify.
      """

      assert_same(expected, actual)
    end
  end
end
