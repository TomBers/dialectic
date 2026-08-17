defmodule Dialectic.Responses.PromptsStructuredTest do
  use ExUnit.Case, async: true

  alias Dialectic.Responses.PromptsStructured

  describe "system_preamble/1" do
    test "defines the fast, child-accessible Standard contract" do
      prompt = PromptsStructured.system_preamble(:high_school)

      assert prompt =~ "Complexity level: Standard"
      assert prompt =~ "curious seven-year-old"
      assert prompt =~ "everyday words, short sentences, concrete examples"
      assert prompt =~ "Aim for a normal response body of roughly 150-250 words"
      assert prompt =~ "a few short, focused paragraphs"
      assert prompt =~ "Split a paragraph whenever it starts carrying more than one main idea"
      assert prompt =~ "Do not perform source research"
      assert prompt =~ "Do not supply direct quotations"
      refute prompt =~ "## Sources` containing"
    end

    test "defines the high-school-level Detailed contract" do
      prompt = PromptsStructured.system_preamble(:university)

      assert prompt =~ "Complexity level: Detailed"
      assert prompt =~ "motivated high-school reader"
      assert prompt =~ "Aim for a normal response body of roughly 300-550 words"
      assert prompt =~ "enough descriptive `##` sections"
      assert prompt =~ "Keep each paragraph focused on one idea"
      assert prompt =~ "compact list, a brief blockquote, or a comparison table"
      assert prompt =~ "renders citations directly from provider grounding metadata"
      assert prompt =~ "peer-reviewed research"
      assert prompt =~ "normally 3-5 distinct sources and no more than 6"
      assert prompt =~ "instead of adding near-duplicate sources"
      assert prompt =~ "Begin research with searches targeting the relevant academic"
      assert prompt =~ "may provide supplementary context"
      assert prompt =~ "site:.edu"

      assert prompt =~
               "aim to include one or two brief direct quotations whose exact wording adds analytical value"

      assert prompt =~ "quotations do not need matching provider-grounded URLs"
      assert prompt =~ "omit an uncertain locator rather than inventing one"

      assert prompt =~ "Do not add a sources or references section"
    end

    test "defines the university-level Expert contract" do
      prompt = PromptsStructured.system_preamble(:expert)

      assert prompt =~ "Complexity level: Expert"
      assert prompt =~ "university level for an undergraduate reader"
      assert prompt =~ "do not assume postgraduate expertise"
      assert prompt =~ "Aim for a normal response body of roughly 450-750 words"
      assert prompt =~ "several descriptive `##` sections"
      assert prompt =~ "Keep each paragraph focused on one analytical move"
      assert prompt =~ "renders citations directly from provider grounding metadata"
      assert prompt =~ "university-press works"
      assert prompt =~ "smallest source set that adequately supports the answer"
      assert prompt =~ "unless the user explicitly requests a broad literature review"
      assert prompt =~ "Give primary and scholarly sources the greatest evidential weight"
      assert prompt =~ "should not displace stronger sources"
      assert prompt =~ "carry a material claim on their own"

      assert prompt =~
               "use several brief direct quotations where their exact wording adds analytical value"

      assert prompt =~ "rather than forcing a fixed count"
      assert prompt =~ "quotations do not need matching provider-grounded URLs"
      assert prompt =~ "author and work"

      assert prompt =~ "Do not add a sources or references section"
    end

    test "keeps common integrity, Markdown, and graph-continuity rules" do
      for mode <- [:high_school, :university, :expert] do
        prompt = PromptsStructured.system_preamble(mode)

        assert prompt =~ "Never invent or guess quotations"
        assert prompt =~ "Direct quotations and provider-grounded source links are separate"
        assert prompt =~ "does not need a matching grounded URL"
        assert prompt =~ "If the wording is uncertain, paraphrase it"
        assert prompt =~ "Do not add a sources or references section"
        assert prompt =~ "If grounded evidence is unavailable, do not invent"
        assert prompt =~ "Return only valid GitHub Flavored Markdown"
        assert prompt =~ "Start with one concise `#` title"
        assert prompt =~ "Use descriptive `##` headings"
        assert prompt =~ "Never produce ASCII art"
        assert prompt =~ "Add genuinely new information"
        assert prompt =~ "Check that the answer is proportionate, readable, complete"
      end
    end

    test "provides progressively larger output and opening ranges" do
      standard = PromptsStructured.response_profile(:high_school)
      detailed = PromptsStructured.response_profile(:university)
      expert = PromptsStructured.response_profile(:expert)

      assert {standard.min_words, standard.max_words, standard.max_output_tokens} ==
               {150, 250, 2_048}

      assert {detailed.min_words, detailed.max_words, detailed.max_output_tokens} ==
               {300, 550, 4_096}

      assert {expert.min_words, expert.max_words, expert.max_output_tokens} ==
               {450, 750, 8_192}

      assert PromptsStructured.initial_word_range(:high_school) == "250-350 words"
      assert PromptsStructured.initial_word_range(:university) == "400-650 words"
      assert PromptsStructured.initial_word_range(:expert) == "550-850 words"
    end

    test "maps legacy simple values to Standard" do
      prompt = PromptsStructured.system_preamble(:simple)

      assert prompt =~ "Complexity level: Standard"
      assert PromptsStructured.response_profile(:simple).key == "high_school"
      assert PromptsStructured.max_output_tokens(:simple) == 2_048
    end

    test "normalizes string and unsupported modes before building the prompt" do
      assert PromptsStructured.system_preamble("high_school") =~ "Complexity level: Standard"
      assert PromptsStructured.system_preamble("university") =~ "Complexity level: Detailed"
      assert PromptsStructured.system_preamble("expert") =~ "Complexity level: Expert"
      assert PromptsStructured.system_preamble("simple") =~ "Complexity level: Standard"
      assert PromptsStructured.system_preamble(:unknown) =~ "Complexity level: Detailed"
      assert PromptsStructured.system_preamble("unknown") =~ "Complexity level: Detailed"
    end

    test "recovers the snapshotted mode from application and legacy prompts" do
      for mode <- [:high_school, :university, :expert] do
        prompt = PromptsStructured.system_preamble(mode)
        assert PromptsStructured.mode_from_preamble(prompt) == {:ok, mode}
      end

      assert PromptsStructured.mode_from_preamble("Complexity level: Simple") ==
               {:ok, :high_school}

      assert PromptsStructured.mode_from_preamble("Complexity level: High School") ==
               {:ok, :high_school}

      assert PromptsStructured.mode_from_preamble("Complexity level: University") ==
               {:ok, :university}

      assert PromptsStructured.mode_from_preamble("Custom system prompt") == :error
    end
  end
end
