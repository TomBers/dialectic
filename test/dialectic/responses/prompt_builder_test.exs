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
      Start your answer with:
      ## Response
      Answer "Explain recursion" directly with short paragraphs. Length: ~120–220 words. If the topic is abstract, include one concrete example. You may end with a 2–4‑bullet Checklist if it adds value.
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
      Start your answer with:
      ## Selection
      Rewrite the highlighted passage more clearly with one concrete example; then paraphrase why it matters to the current context. If no selection is present, say so and ask for it in one sentence. If the selection is already clear, improve micro‑clarity (shorter sentences, concrete nouns/verbs) rather than expanding.

      Return with these sections:
      ### Rewritten — cleaner phrasing + one concrete example.
      ### Why it matters here — 1–3 sentences tying it to the current task/context.
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
      Start your answer with:
      ## Synthesis
      Compare "Type systems prevent runtime errors" and "Dynamic typing increases flexibility". Length: ~120–180 words.
      Use this structure:
      ### Common ground — 2–3 bullets.
      ### Tensions — 2–3 bullets (specific).
      ### Synthesis / Scope boundary — one compact paragraph or 2–3 bullets with when‑to‑use‑which.
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
      Start your answer with:
      ## Thesis
      Make a brief, rigorous case for "Functional programming improves testability". Length: ~100–160 words.
      Use this structure:
      ### Claim — one sentence.
      ### Reasoning — 3 bullets, each a distinct argument.
      ### Example — 2–3 sentences.
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
      Start your answer with:
      ## Antithesis
      Critique "Microservices are always better than monoliths" rigorously. Length: ~120–180 words.
      Use this structure:
      ### Steelman — the best case for the claim.
      ### Core objection — the key flaw or boundary.
      ### Support / Counterexample — 2–4 sentences.
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
      Start your answer with:
      ## Related ideas
      Suggest diverse, related concepts to explore next for "Event Sourcing in Distributed Systems". Return 6–8 bullets; each bullet: Concept — one‑sentence rationale or contrast. Total ≤120 words.
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
      Start your answer with:
      ## Deepdive
      Explain "Bayes' theorem" rigorously for an advanced learner. Length: 2–4 compact paragraphs (~140–220 words).
      Use this structure:
      Paragraph 1: core definition and intuition.
      Paragraph 2: formal relationship/mechanics.
      Paragraph 3: Assumptions & Scope (explicit).
      Optional: Brief Caveats if they reduce misuse.
      """

      assert_same(expected, actual)
    end
  end
end
