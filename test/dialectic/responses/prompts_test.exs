defmodule Dialectic.Responses.PromptsTest do
  use ExUnit.Case, async: true

  alias Dialectic.Responses.Prompts

  # Note: frame_minimal_context/1 is a private function, so we test it indirectly
  # through the public selection/2 function which uses it internally

  describe "selection/2 - minimal context behavior" do
    test "includes context when shorter than max length (1000 characters)" do
      short_context = "This is a short context that is well under the 1000 character limit."
      selection_text = "test selection"
      result = Prompts.selection(short_context, selection_text)

      assert result =~ "### Foundation (for reference)"
      assert result =~ short_context
      assert result =~ "Background context. You may reference this but are not bound by it."
    end

    test "truncates context when longer than max length (1000 characters)" do
      # Create a string longer than 1000 characters
      long_context = String.duplicate("a", 1500)
      selection_text = "test selection"
      result = Prompts.selection(long_context, selection_text)

      # Should still include the Foundation section
      assert result =~ "### Foundation (for reference)"
      # Should include truncated content with indicator
      assert result =~ "[... truncated for brevity ...]"
      # Should not include the full long context
      refute result =~ long_context
      assert result =~ selection_text
    end

    test "includes full context at exactly 999 characters (just under max)" do
      edge_case_context = String.duplicate("x", 999)
      selection_text = "test selection"
      result = Prompts.selection(edge_case_context, selection_text)

      assert result =~ "### Foundation (for reference)"
      assert result =~ edge_case_context
      refute result =~ "[... truncated for brevity ...]"
    end

    test "truncates context at exactly 1000 characters (at threshold)" do
      edge_case_context = String.duplicate("x", 1001)
      selection_text = "test selection"
      result = Prompts.selection(edge_case_context, selection_text)

      assert result =~ "### Foundation (for reference)"
      assert result =~ "[... truncated for brevity ...]"
    end

    test "handles empty string context" do
      selection_text = "test selection"
      result = Prompts.selection("", selection_text)

      assert result =~ "### Foundation (for reference)"
      # Should still include the structure, just with empty content
      assert result =~ "```text"
    end

    test "handles whitespace-only context" do
      whitespace_context = "   \n\t  "
      selection_text = "test selection"
      result = Prompts.selection(whitespace_context, selection_text)

      assert result =~ "### Foundation (for reference)"
      assert result =~ whitespace_context
    end

    test "preserves markdown formatting in short context" do
      markdown_context = "# Title\n\n- List item\n- Another item"
      selection_text = "test selection"
      result = Prompts.selection(markdown_context, selection_text)

      assert result =~ markdown_context
      assert result =~ "```text"
      refute result =~ "[... truncated for brevity ...]"
    end

    test "truncates long context preserving beginning" do
      # Create a context with identifiable start and end
      long_context = "START_MARKER" <> String.duplicate("x", 1000) <> "END_MARKER"
      selection_text = "test selection"
      result = Prompts.selection(long_context, selection_text)

      # Should include the start
      assert result =~ "START_MARKER"
      # Should not include the end (truncated)
      refute result =~ "END_MARKER"
      assert result =~ "[... truncated for brevity ...]"
    end
  end

  describe "selection/2 - general behavior" do
    test "always includes context with minimal framing" do
      short_context = "Brief background information"
      selection_text = "consciousness"

      result = Prompts.selection(short_context, selection_text)

      assert result =~ "### Foundation (for reference)"
      assert result =~ short_context
      assert result =~ selection_text
      assert result =~ "new exploration starting point"
    end

    test "truncates long contexts while maintaining foundation structure" do
      long_context = String.duplicate("a", 1500)
      selection_text = "consciousness"

      result = Prompts.selection(long_context, selection_text)

      # Should still have Foundation section, just truncated
      assert result =~ "### Foundation (for reference)"
      assert result =~ "[... truncated for brevity ...]"
      assert result =~ selection_text
      assert result =~ "new exploration starting point"
    end

    test "includes selection text in the instruction" do
      context = "Some context"
      selection_text = "Lacanian psychoanalysis"

      result = Prompts.selection(context, selection_text)

      assert result =~
               "A specific topic was highlighted from the text above: **#{selection_text}**"
    end

    test "encourages divergence from original discussion" do
      context = "Context about quantum mechanics"
      selection_text = "observer effect"

      result = Prompts.selection(context, selection_text)

      assert result =~
               "focus on depth and breadth regarding THIS specific concept"
    end
  end

  describe "explain/2" do
    test "uses full context framing" do
      context = "Previous discussion about a topic"
      topic = "What is philosophy?"

      result = Prompts.explain(context, topic)

      assert result =~ "### Foundation"
      assert result =~ "The following has already been explored:"
      assert result =~ context
      assert result =~ topic
    end

    test "emphasizes adding new insights" do
      context = "Background"
      topic = "Ethics"

      result = Prompts.explain(context, topic)

      assert result =~ "ADDING new perspectives"
      assert result =~ "EXTEND BEYOND"
      assert result =~ "Do not repeat or merely rephrase"
    end
  end

  describe "initial_explainer/2" do
    test "generates initial answer prompt with exploration suggestions" do
      context = "Background context"
      topic = "What is quantum entanglement?"

      result = Prompts.initial_explainer(context, topic)

      assert result =~ topic
      assert result =~ "extension questions"
      assert result =~ "Build on the Foundation"
    end
  end

  describe "synthesis/4" do
    test "combines two positions with their contexts" do
      context1 = "First position context"
      context2 = "Second position context"
      pos1 = "Thesis statement"
      pos2 = "Antithesis statement"

      result = Prompts.synthesis(context1, context2, pos1, pos2)

      assert result =~ pos1
      assert result =~ pos2
      assert result =~ "Synthesize these positions"
      assert result =~ "Common ground"
    end
  end

  describe "thesis/2" do
    test "generates prompt for supporting a claim" do
      context = "Discussion context"
      claim = "Democracy is the best form of government"

      result = Prompts.thesis(context, claim)

      assert result =~ claim
      assert result =~ "IN FAVOR OF"
      assert result =~ "strong argument"
    end
  end

  describe "antithesis/2" do
    test "generates prompt for opposing a claim" do
      context = "Discussion context"
      claim = "Technology always improves society"

      result = Prompts.antithesis(context, claim)

      assert result =~ claim
      assert result =~ "AGAINST"
      assert result =~ "counterarguments"
    end
  end

  describe "related_ideas/2" do
    test "generates prompt for finding adjacent topics" do
      context = "Current exploration context"
      current_idea = "Existentialism"

      result = Prompts.related_ideas(context, current_idea)

      assert result =~ current_idea
      assert result =~ "3-5 adjacent topics"
      assert result =~ "thinkers, or concepts"
    end
  end

  describe "deep_dive/2" do
    test "generates prompt for in-depth exploration" do
      context = "Overview of the topic"
      topic = "Machine Learning"

      result = Prompts.deep_dive(context, topic)

      assert result =~ topic
      assert result =~ "deep dive"
      assert result =~ "BEYOND the overview"
      assert result =~ "beyond normal 500-word limit"
    end
  end
end
