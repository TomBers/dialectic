defmodule Dialectic.Responses.LlmInterface do
  alias Dialectic.Responses.RequestQueue

  def gen_response(node, child, graph_id, live_view_topic) do
    context = GraphManager.build_context(graph_id, node)

    qn = """
    Context:
    #{context}

    Task: Teach a first‑time learner aiming for a university‑level understanding of: "#{node.content}"

    Output (markdown):
    ## [Short, descriptive title]
    - Short answer (2–3 sentences) giving the core idea and why it matters.

    ### Deep dive
    - Foundations: 3–4 bullets defining key terms and stating assumptions.
    - Model/mechanism: 3–5 bullets explaining how it works; include one line of minimal formalism (equation or pseudocode) if appropriate and define symbols.
    - Worked example: 3–4 concise steps that show the idea in action.
    - Nuances: 2–3 bullets on pitfalls, edge cases, or common confusions; include one contrast with a neighboring idea.

    ### Next steps and sources
    - Next questions to explore (1–2).
    - Further reading (2–3 items): Title — Source (URL) or, if unsure, a precise search query with what is uncertain.

    Constraints: Aim for depth over breadth; ~220–320 words excluding references.
    """

    ask_model(qn, child, graph_id, live_view_topic)
  end

  def gen_selection_response(node, child, graph_id, selection, live_view_topic) do
    context = GraphManager.build_context(graph_id, node)

    default_schema = """
    Output (markdown):
    ## [Short, descriptive title]
    - Paraphrase (1–2 sentences) of the selection in your own words.

    ### Why it matters here
    - Claims and evidence (2–3 bullets).
    - Assumptions/definitions you’re relying on (1–2 bullets).
    - Implications for the current context (1–2 bullets).
    - Limitations or alternative readings (1–2 bullets).

    ### Next steps and sources
    - Follow‑up questions (1–2).
    - Further reading (1–2 items): Title — Source (URL) or a precise search query.

    Constraints: ~180–260 words excluding references.
    """

    add_default? =
      not Regex.match?(
        ~r/(^|\n)Output\s*\(|(^|\n)##\s|(^|\n)###\s|Return only|Headings?:|Subsections?:/im,
        selection
      )

    qn =
      """
      Context:
      #{context}

      Instruction (apply to the context and current node):
      #{selection}

      Audience: first-time learner aiming for university-level understanding.
      """ <> if add_default?, do: "\n\n" <> default_schema, else: ""

    ask_model(qn, child, graph_id, live_view_topic)
  end

  def gen_synthesis(n1, n2, child, graph_id, live_view_topic) do
    # TODO - Add n2 context ?? need to enforce limit??
    context1 = GraphManager.build_context(graph_id, n1)
    context2 = GraphManager.build_context(graph_id, n2)

    qn =
      """
      Context of first argument:
      #{context1}

      Context of second argument:
      #{context2}

      Task: Synthesize the positions in "#{n1.content}" and "#{n2.content}" for a first-time learner aiming for university-level understanding.

      Output (markdown):
      ## [Short, descriptive title]
      - Short summary (1–2 sentences) of the relationship between the two positions.

      ### Deep dive
      - Common ground (2 bullets) with language and definitions aligned.
      - Key tension (2 bullets) specifying assumptions that drive disagreement.
      - Synthesis/bridge (2–3 bullets) that could reconcile or delineate scope; include a testable prediction.
      - When each view is stronger (1–2 bullets).
      - Trade‑offs or unknowns (1–2 bullets).

      ### Next steps and sources
      - One concrete next step to test or explore.
      - Further reading (1–3 items): Title — Source (URL) or a precise search query.

      Constraints: ~220–320 words excluding references. If reconciliation is not possible, state the trade‑offs clearly.
      """

    ask_model(qn, child, graph_id, live_view_topic)
  end

  def gen_thesis(node, child, graph_id, live_view_topic) do
    context = GraphManager.build_context(graph_id, node)

    qn = """
    Context:
    #{context}

    Write a short, beginner-friendly but rigorous argument in support of: "#{node.content}"

    Output (markdown):
    ## [Title of the pro argument]
    - Claim (1 sentence).
    - Line of reasoning (3 bullets), each grounded in a mechanism, formal result, or empirical evidence; cite the source type (e.g., "randomized trial", "textbook theorem", "official spec").
    - Illustrative example or evidence (1–2 lines).
    - Assumptions and limits (1 line) plus a falsifiable prediction.
    - When this holds vs. when it might not (1 line).
    - Further reading (1–2 items): Title — Source (URL) or a precise search query.

    Constraints: 150–200 words excluding references.
    """

    ask_model(qn, child, graph_id, live_view_topic)
  end

  def gen_antithesis(node, child, graph_id, live_view_topic) do
    context = GraphManager.build_context(graph_id, node)

    qn = """
    Context:
    #{context}

    Write a short, beginner-friendly but rigorous argument against: "#{node.content}"
    Steelman the opposing view (represent the strongest version fairly).

    Output (markdown):
    ## [Title of the con argument]
    - Central critique (1 sentence).
    - Line of reasoning (3 bullets), each grounded in a mechanism, formal result, or empirical evidence; cite the source type when relevant.
    - Illustrative counterexample or evidence (1–2 lines).
    - Scope and limits (1 line) plus a falsifiable prediction that would weaken this critique.
    - When this criticism applies vs. when it might not (1 line).
    - Further reading (1–2 items): Title — Source (URL) or a precise search query.

    Constraints: 150–200 words excluding references.
    """

    ask_model(qn, child, graph_id, live_view_topic)
  end

  def gen_related_ideas(node, child, graph_id, live_view_topic) do
    context = GraphManager.build_context(graph_id, node)

    content =
      node
      |> case do
        nil -> ""
        n -> to_string(n.content || "")
      end

    content1 = String.replace(content, "**", "")
    content2 = Regex.replace(~r/^Title:\s*/i, content1, "")
    first_line = content2 |> String.split("\n") |> Enum.at(0) |> to_string()
    stripped = Regex.replace(~r/^\s*[#]{1,6}\s*/, first_line, "")
    title = String.trim(stripped)

    qn = """
    Context:
    #{context}

    Generate a beginner-friendly list of related but distinct concepts to explore.

    Current idea: "#{title}"

    Requirements:
    - Do not repeat or restate the current idea; prioritize diversity and contrasting schools of thought.
    - Include at least one explicitly contrasting perspective (for example, if the topic is behaviourism, include psychodynamics).
    - Audience: first-time learner.

    Output (markdown only; return only the list):
    - Create 3 short subsections with H3 headings:
      ### Different/contrasting approaches
      ### Adjacent concepts
      ### Practical applications
    - Under each heading, list 3–4 bullets.
    - Each bullet: Concept — 1 sentence on why it’s relevant and how it differs; add one named method/author or canonical example if relevant.
    - Use plain language and avoid jargon.

    Return only the headings and bullets; no intro or outro.
    """

    ask_model(qn, child, graph_id, live_view_topic)
  end

  def gen_deepdive(node, child, graph_id, live_view_topic) do
    context = to_string(node.content || "")

    qn = """
    Context:
    #{context}

    Task: Produce a rigorous, detailed deep dive into "#{node.content}" for an advanced learner progressing toward research-level understanding.

    Output (markdown):
    ## [Precise title]
    - One-sentence statement of what the concept is and when it applies.

    ### Deepdive
    - A deep engagement with the concept

    Constraints: Aim for technical clarity and depth; ~350–500 words.
    """

    ask_model(qn, child, graph_id, live_view_topic)
  end

  def ask_model(question, to_node, graph_id, live_view_topic) do
    style = """
    You are teaching a curious beginner toward university-level mastery.
    - Start with intuition, then add precise definitions and assumptions.
    - Prefer causal/mechanistic explanations. When appropriate, include minimal formalism (one compact equation or pseudocode) and define all symbols; skip if not relevant.
    - Use short paragraphs and well-structured bullets. Avoid over-fragmented checklists.
    - If context is insufficient, say what’s missing and ask one clarifying question.
    - Prefer info from the provided Context; label other info as "Background".
    - Never fabricate citations or data. Include 1–3 trustworthy references formatted: Title — Source (URL). If unsure, provide a precise search query and state what is uncertain.
    - Avoid tables; use headings and bullets only.
    Default to markdown and an H2 title (## …) unless the instruction specifies otherwise. When there is any conflict, follow the question/selection’s format and instructions.
    """

    RequestQueue.add(
      style <> "\n\n" <> question,
      to_node,
      graph_id,
      live_view_topic
    )
  end
end
