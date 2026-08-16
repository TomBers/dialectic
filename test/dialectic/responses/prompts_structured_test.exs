defmodule Dialectic.Responses.PromptsStructuredTest do
  use ExUnit.Case, async: true

  alias Dialectic.Responses.PromptsStructured

  describe "system_preamble/1" do
    test "defines the fast, child-accessible Standard contract" do
      prompt = PromptsStructured.system_preamble(:high_school)

      assert prompt =~ "Complexity level: Standard"
      assert prompt =~ "curious seven-year-old"
      assert prompt =~ "everyday words, short sentences, concrete examples"
      assert prompt =~ "Normal response body: 150-250 words"
      assert prompt =~ "2-4 short paragraphs"
      assert prompt =~ "no more than 60 words each"
      assert prompt =~ "Do not perform source research"
      assert prompt =~ "Do not supply direct quotations"
      refute prompt =~ "## Sources` containing"
    end

    test "defines the high-school-level Detailed contract" do
      prompt = PromptsStructured.system_preamble(:university)

      assert prompt =~ "Complexity level: Detailed"
      assert prompt =~ "motivated high-school reader"
      assert prompt =~ "Normal response body: 300-550 words"
      assert prompt =~ "2-4 descriptive `##` sections"
      assert prompt =~ "paragraphs normally below 70 words"
      assert prompt =~ "compact list, a verified blockquote, or a comparison table"
      assert prompt =~ "`## Sources` containing 2-4 useful sources"
      assert prompt =~ "include exactly one brief verified direct quote"
    end

    test "defines the university-level Expert contract" do
      prompt = PromptsStructured.system_preamble(:expert)

      assert prompt =~ "Complexity level: Expert"
      assert prompt =~ "university level for an undergraduate reader"
      assert prompt =~ "do not assume postgraduate expertise"
      assert prompt =~ "Normal response body: 450-750 words"
      assert prompt =~ "3-5 descriptive `##` sections"
      assert prompt =~ "paragraphs normally below 80 words"
      assert prompt =~ "`## Sources` containing 4-6 strong sources"
      assert prompt =~ "include 1-2 brief verified direct quotes"
    end

    test "keeps common integrity, Markdown, and graph-continuity rules" do
      for mode <- [:high_school, :university, :expert] do
        prompt = PromptsStructured.system_preamble(mode)

        assert prompt =~ "Never invent or guess quotations"
        assert prompt =~ "Return only valid GitHub Flavored Markdown"
        assert prompt =~ "Start with one concise `#` title"
        assert prompt =~ "Use descriptive `##` headings"
        assert prompt =~ "Never produce ASCII art"
        assert prompt =~ "Add genuinely new information"
        assert prompt =~ "Verify body length, required section count, paragraph length"
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
