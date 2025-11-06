defmodule Dialectic.Responses.PromptsTest do
  use ExUnit.Case, async: true

  alias Dialectic.Responses.Prompts

  setup do
    context = "Graph context for node A"
    topic = "Reinforcement learning"
    {:ok, context: context, topic: topic}
  end

  describe "explain/2" do
    test "formats core sections and interpolates topic", %{context: c, topic: t} do
      prompt = Prompts.explain(c, t)
      assert prompt =~ "You are teaching a curious beginner"
      assert prompt =~ "Context:\n" <> c

      assert prompt =~
               ~s/Task: Teach a first‑time learner aiming for a university‑level understanding of: "#{t}"/

      assert prompt =~ "## [Short, descriptive title]"
      assert prompt =~ "### Deep dive"
      assert prompt =~ "Constraints: Aim for depth over breadth"
    end
  end

  describe "selection/2" do
    test "adds default output schema when selection lacks headings", %{context: c} do
      sel = "Summarize the key claims."
      prompt = Prompts.selection(c, sel)

      assert prompt =~ "Instruction (apply to the context and current node):\n" <> sel
      assert prompt =~ "Audience: first-time learner aiming for university-level understanding."
      # Default schema fragments
      assert prompt =~ "Output (markdown):"
      assert prompt =~ "## [Short, descriptive title]"
      assert prompt =~ "### Why it matters here"
      assert prompt =~ "Constraints: ~180–260 words."
    end

    test "does not add default schema when selection includes headings", %{context: c} do
      sel = """
      Please analyze the argument.
      ## Custom heading
      Return only the bullets.
      """

      prompt = Prompts.selection(c, sel)

      assert prompt =~ "Instruction (apply to the context and current node):"
      # Should not include default schema sections
      refute prompt =~ "### Why it matters here"
    end

    test "does not add default schema when selection includes Output(...)", %{context: c} do
      sel = "Output (markdown):\n## Custom"
      prompt = Prompts.selection(c, sel)
      refute prompt =~ "### Why it matters here"
    end
  end

  describe "synthesis/4" do
    test "includes both contexts and positions" do
      p = Prompts.synthesis("C1", "C2", "A", "B")
      assert p =~ "Context of first argument:\nC1"
      assert p =~ "Context of second argument:\nC2"
      assert p =~ ~s/Task: Synthesize the positions in "A" and "B"/
      assert p =~ "### Deep dive"
      assert p =~ "Constraints: ~220–320 words."
    end
  end

  describe "thesis/2 and antithesis/2" do
    test "thesis has expected sections and constraints" do
      p = Prompts.thesis("CTX", "My claim")
      assert p =~ "Context:\nCTX"
      assert p =~ ~s/in support of: "My claim"/
      assert p =~ "## [Title of the pro argument]"
      assert p =~ "Constraints: 150–200 words."
    end

    test "antithesis includes steelman instruction" do
      p = Prompts.antithesis("CTX", "Their claim")
      assert p =~ "Context:\nCTX"
      assert p =~ ~s/against: "Their claim"/
      assert p =~ "Steelman the opposing view"
      assert p =~ "## [Title of the con argument]"
      assert p =~ "Constraints: 150–200 words."
    end
  end

  describe "related_ideas/2" do
    test "produces three requested H3 sections and return-only instruction" do
      p = Prompts.related_ideas("CTX", "Topic X")
      assert p =~ "Context:\nCTX"
      assert p =~ ~s/Current idea: "Topic X"/
      assert p =~ "Output (markdown only; return only the list):"
      assert p =~ "### Different/contrasting approaches"
      assert p =~ "### Adjacent concepts"
      assert p =~ "### Practical applications"
      assert p =~ "Return only the headings and bullets; no intro or outro."
    end
  end

  describe "extract_title/1" do
    test "strips bold markers, Title: prefix, heading markers and trims" do
      assert Prompts.extract_title("**Title: **  \n##  My Heading  ") == "My Heading"
    end

    test "returns first line without markdown heading markers" do
      assert Prompts.extract_title("###   Deep Learning\nMore text") == "Deep Learning"
    end

    test "handles nil content" do
      assert Prompts.extract_title(nil) == ""
    end
  end

  describe "deep_dive/2" do
    test "contains task, deep dive section and constraints" do
      p = Prompts.deep_dive("CTX", "Tensor calculus")
      assert p =~ "Context:\nCTX"
      assert p =~ ~s/Task: Produce a rigorous, detailed deep dive into "Tensor calculus"/
      assert p =~ "### Deep dive"
      assert p =~ "Constraints: Aim for clarity and concision; ~280–420 words."
    end
  end
end
