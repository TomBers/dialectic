defmodule Dialectic.Responses.LlmPromptsTest do
  use Dialectic.DataCase, async: false
  use Oban.Testing, repo: Dialectic.Repo

  require Logger

  alias Dialectic.Responses.LlmInterface
  alias Dialectic.Responses.Modes
  alias Dialectic.DbActions.Graphs
  alias Dialectic.Graph.Vertex

  defp unique_graph_id(prefix \\ "prompts") do
    prefix <> "-" <> Ecto.UUID.generate()
  end

  defp fetch_enqueued_question!(graph_id, to_node_id) do
    job =
      all_enqueued(worker: Elixir.Dialectic.Workers.LocalWorker)
      |> Enum.find(fn %Oban.Job{args: args} ->
        args["graph"] == graph_id and args["to_node"] == to_node_id
      end)

    case job do
      %Oban.Job{args: %{"question" => q}} ->
        q

      _ ->
        flunk("Expected LocalWorker job not found for graph=#{graph_id}, to_node=#{to_node_id}")
    end
  end

  defp normalize(str) do
    str
    |> to_string()
    |> String.split("\n")
    |> Enum.map(&String.trim_leading/1)
    |> Enum.reject(&String.starts_with?(&1, "Context"))
    |> Enum.join("\n")
    |> String.trim()
    |> String.replace(~r/\n{2,}/, "\n")
  end

  defp assert_contains_normalized(haystack, needle) do
    norm_hay = normalize(haystack)
    norm_need = normalize(needle)

    assert String.contains?(norm_hay, norm_need),
           """
           Expected normalized prompt to contain:

           #{norm_need}

           But actual normalized prompt was:

           #{norm_hay}
           """
  end

  describe "gen_response/5 prompt" do
    test "snapshots the generated question text" do
      mode = :structured
      graph_id = unique_graph_id("gen_response")
      {:ok, _} = Graphs.create_new_graph(graph_id)
      GraphManager.get_graph(graph_id)

      node = %Vertex{id: "n1", content: "Explain recursion"}
      child = %Vertex{id: "c1"}

      # Build and enqueue
      _ = LlmInterface.gen_response(node, child, graph_id, "topic", mode)

      # Capture the fully composed prompt (system + mode + question)
      composed = fetch_enqueued_question!(graph_id, child.id)
      Logger.warning("gen_response prompt:\n" <> composed)

      # Assert the system part is present
      assert String.starts_with?(composed, Modes.base_style())
      assert String.contains?(composed, Modes.mode_prompt(mode))

      # Assert the specific instruction block
      expected_instr = """
      Context:

      Instruction:


      Answer "Explain recursion" directly with short paragraphs. Length: ~120–220 words. If the topic is abstract, include one concrete example. You may end with a 2–4‑bullet Checklist if it adds value.
      """

      assert_contains_normalized(composed, expected_instr)
    end
  end

  describe "gen_selection_response/6 prompt" do
    test "snapshots the generated question text including default schema" do
      mode = :structured
      graph_id = unique_graph_id("gen_selection")
      {:ok, _} = Graphs.create_new_graph(graph_id)
      GraphManager.get_graph(graph_id)

      node = %Vertex{id: "n2", content: "Selection context holder"}
      child = %Vertex{id: "c2"}
      selection = "Rewrite the highlighted passage more clearly."

      _ = LlmInterface.gen_selection_response(node, child, graph_id, selection, "topic", mode)

      composed = fetch_enqueued_question!(graph_id, child.id)
      Logger.warning("gen_selection_response prompt:\n" <> composed)

      assert String.starts_with?(composed, Modes.base_style())
      assert String.contains?(composed, Modes.mode_prompt(mode))

      expected = """
      Context:

      Instruction (apply to the context and current node):
      Rewrite the highlighted passage more clearly.

      Instruction:
      Rewrite the highlighted passage more clearly with one concrete example; then paraphrase why it matters to the current context. If no selection is present, say so and ask for it in one sentence. If the selection is already clear, improve micro‑clarity (shorter sentences, concrete nouns/verbs) rather than expanding.

      Return with these sections:
      ### Rewritten — cleaner phrasing + one concrete example.
      ### Why it matters here — 1–3 sentences tying it to the current task/context.
      """

      norm = normalize(composed)

      assert String.contains?(
               norm,
               normalize("""
               Instruction (apply to the context and current node):
               Rewrite the highlighted passage more clearly.
               """)
             )

      assert String.contains?(
               norm,
               normalize("""
               Instruction:
               Rewrite the highlighted passage more clearly with one concrete example; then paraphrase why it matters to the current context. If no selection is present, say so and ask for it in one sentence. If the selection is already clear, improve micro‑clarity (shorter sentences, concrete nouns/verbs) rather than expanding.

               Return with these sections:
               ### Rewritten — cleaner phrasing + one concrete example.
               ### Why it matters here — 1–3 sentences tying it to the current task/context.
               """)
             )
    end
  end

  describe "gen_synthesis/6 prompt" do
    test "snapshots the generated question text for two nodes" do
      mode = :structured
      graph_id = unique_graph_id("gen_synthesis")
      {:ok, _} = Graphs.create_new_graph(graph_id)
      GraphManager.get_graph(graph_id)

      n1 = %Vertex{id: "n3a", content: "Type systems prevent runtime errors"}
      n2 = %Vertex{id: "n3b", content: "Dynamic typing increases flexibility"}
      child = %Vertex{id: "c3"}

      _ = LlmInterface.gen_synthesis(n1, n2, child, graph_id, "topic", mode)

      composed = fetch_enqueued_question!(graph_id, child.id)
      Logger.warning("gen_synthesis prompt:\n" <> composed)

      assert String.starts_with?(composed, Modes.base_style())
      assert String.contains?(composed, Modes.mode_prompt(mode))

      # Match the core shape; avoid brittle unicode hyphen differences by checking core phrases
      assert_contains_normalized(composed, """
      Context of first argument:

      Context of second argument:

      Instruction:
      Compare "Type systems prevent runtime errors" and "Dynamic typing increases flexibility". Length: ~120–180 words.
      Use this structure:
      ### Common ground — 2–3 bullets.
      ### Tensions — 2–3 bullets (specific).
      ### Synthesis / Scope boundary — one compact paragraph or 2–3 bullets with when‑to‑use‑which.
      """)
    end
  end

  describe "gen_thesis/5 prompt" do
    test "snapshots the generated question text" do
      mode = :structured
      graph_id = unique_graph_id("gen_thesis")
      {:ok, _} = Graphs.create_new_graph(graph_id)
      GraphManager.get_graph(graph_id)

      node = %Vertex{id: "n4", content: "Functional programming improves testability"}
      child = %Vertex{id: "c4"}

      _ = LlmInterface.gen_thesis(node, child, graph_id, "topic", mode)

      composed = fetch_enqueued_question!(graph_id, child.id)
      Logger.warning("gen_thesis prompt:\n" <> composed)

      assert String.starts_with?(composed, Modes.base_style())
      assert String.contains?(composed, Modes.mode_prompt(mode))

      assert_contains_normalized(composed, """
      Context:

      Instruction:
      Make a brief, rigorous case for "Functional programming improves testability". Length: ~100–160 words.
      Use this structure:
      ### Claim — one sentence.
      ### Reasoning — 3 bullets, each a distinct argument.
      ### Example — 2–3 sentences.
      """)
    end
  end

  describe "gen_antithesis/5 prompt" do
    test "snapshots the generated question text" do
      mode = :structured
      graph_id = unique_graph_id("gen_antithesis")
      {:ok, _} = Graphs.create_new_graph(graph_id)
      GraphManager.get_graph(graph_id)

      node = %Vertex{id: "n5", content: "Microservices are always better than monoliths"}
      child = %Vertex{id: "c5"}

      _ = LlmInterface.gen_antithesis(node, child, graph_id, "topic", mode)

      composed = fetch_enqueued_question!(graph_id, child.id)
      Logger.warning("gen_antithesis prompt:\n" <> composed)

      assert String.starts_with?(composed, Modes.base_style())
      assert String.contains?(composed, Modes.mode_prompt(mode))

      assert_contains_normalized(composed, """
      Context:

      Instruction:
      Critique "Microservices are always better than monoliths" rigorously. Length: ~120–180 words.
      Use this structure:
      ### Steelman — the best case for the claim.
      ### Core objection — the key flaw or boundary.
      ### Support / Counterexample — 2–4 sentences.
      """)
    end
  end

  describe "gen_related_ideas/5 prompt" do
    test "snapshots the generated question text" do
      mode = :structured
      graph_id = unique_graph_id("gen_related_ideas")
      {:ok, _} = Graphs.create_new_graph(graph_id)
      GraphManager.get_graph(graph_id)

      # Include markdown heading to exercise title stripping logic
      node = %Vertex{id: "n6", content: "## Event Sourcing in Distributed Systems"}
      child = %Vertex{id: "c6"}

      _ = LlmInterface.gen_related_ideas(node, child, graph_id, "topic", mode)

      composed = fetch_enqueued_question!(graph_id, child.id)
      Logger.warning("gen_related_ideas prompt:\n" <> composed)

      assert String.starts_with?(composed, Modes.base_style())
      assert String.contains?(composed, Modes.mode_prompt(mode))

      assert_contains_normalized(composed, """
      Context:

      Instruction:


      Suggest diverse, related concepts to explore next for "Event Sourcing in Distributed Systems". Return 6–8 bullets; each bullet: Concept — one‑sentence rationale or contrast. Total ≤120 words.
      """)
    end
  end

  describe "gen_deepdive/5 prompt" do
    test "snapshots the generated question text" do
      mode = :structured
      graph_id = unique_graph_id("gen_deepdive")
      {:ok, _} = Graphs.create_new_graph(graph_id)
      GraphManager.get_graph(graph_id)

      node = %Vertex{id: "n7", content: "Bayes' theorem"}
      child = %Vertex{id: "c7"}

      _ = LlmInterface.gen_deepdive(node, child, graph_id, "topic", mode)

      composed = fetch_enqueued_question!(graph_id, child.id)
      Logger.warning("gen_deepdive prompt:\n" <> composed)

      assert String.starts_with?(composed, Modes.base_style())
      assert String.contains?(composed, Modes.mode_prompt(mode))

      assert_contains_normalized(composed, """
      Context:
      Bayes' theorem

      Instruction:
      Explain "Bayes' theorem" rigorously for an advanced learner. Length: 2–4 compact paragraphs (~140–220 words).
      Use this structure:
      Paragraph 1: core definition and intuition.
      Paragraph 2: formal relationship/mechanics.
      Paragraph 3: Assumptions & Scope (explicit).
      Optional: Brief Caveats if they reduce misuse.
      """)
    end
  end
end
