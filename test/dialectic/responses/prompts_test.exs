defmodule Dialectic.Responses.PromptsTest do
  use ExUnit.Case, async: true

  alias Dialectic.Responses.PromptsStructured

  setup do
    context = "Graph context for node A"
    topic = "Reinforcement learning"
    {:ok, context: context, topic: topic}
  end

  describe "explain/2" do
    test "formats core sections and interpolates topic", %{context: c, topic: t} do
      prompt = PromptsStructured.explain(c, t)
      assert prompt =~ "Inputs: " <> c <> ", " <> t
      assert prompt =~ "Task: Teach a first-time learner " <> t <> "."
      assert prompt =~ "Output (~220–320 words, Markdown):"
      assert prompt =~ "## [Short, descriptive title]"
      assert prompt =~ "### Deep dive"
      assert prompt =~ "### Next steps"
    end
  end

  describe "selection/2" do
    test "includes default output schema", %{context: c} do
      sel = "Summarize the key claims."
      prompt = PromptsStructured.selection(c, sel)

      assert prompt =~ "Inputs: " <> c <> ", " <> sel
      # Default schema fragments
      assert prompt =~ "Output (180–260 words):"
      assert prompt =~ "## [Short, descriptive title]"
      assert prompt =~ "### Why it matters here"
    end

    test "still includes default schema when selection includes headings", %{context: c} do
      sel = """
      Please analyze the argument.
      ## Custom heading
      Return only the bullets.
      """

      prompt = PromptsStructured.selection(c, sel)

      assert prompt =~ "Inputs: " <> c
      assert prompt =~ "### Why it matters here"
    end

    test "still includes default schema when selection includes Output(...)", %{context: c} do
      sel = "Output (markdown):\n## Custom"
      prompt = PromptsStructured.selection(c, sel)
      assert prompt =~ "### Why it matters here"
    end
  end

  describe "synthesis/4" do
    test "includes both contexts and positions" do
      p = PromptsStructured.synthesis("C1", "C2", "A", "B")
      assert p =~ "Context of first argument:\nC1"
      assert p =~ "Context of second argument:\nC2"
      assert p =~ ~s/Task: Synthesize the positions in "A" and "B"/
      assert p =~ "### Deep dive"
      assert p =~ "Constraints: ~220–320 words."
    end
  end

  describe "thesis/2 and antithesis/2" do
    test "thesis has expected sections" do
      p = PromptsStructured.thesis("CTX", "My claim")
      assert p =~ "Inputs: CTX, My claim"
      assert p =~ "## [Title of the pro argument]"
      assert p =~ "Output (150–200 words):"
    end

    test "antithesis outline" do
      p = PromptsStructured.antithesis("CTX", "Their claim")
      assert p =~ "Inputs: CTX, Their claim"
      assert p =~ "## [Title of the con argument]"
      assert p =~ "Output (150–200 words):"
    end
  end

  describe "related_ideas/2" do
    test "produces three requested H3 sections and return-only instruction" do
      p = PromptsStructured.related_ideas("CTX", "Topic X")
      assert p =~ "Inputs: CTX, Topic X"
      assert p =~ "Output (Markdown only; return only headings and bullets):"
      assert p =~ "### Different/contrasting approaches"
      assert p =~ "### Adjacent concepts"
      assert p =~ "### Practical applications"
    end
  end

  describe "deep_dive/2" do
    test "contains deep dive section" do
      p = PromptsStructured.deep_dive("CTX", "Tensor calculus")
      assert p =~ "Inputs: CTX, Tensor calculus"
      assert p =~ "Output (~280–420 words):"
      assert p =~ "### Deep dive"
    end
  end
end
