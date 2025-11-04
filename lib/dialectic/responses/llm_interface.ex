defmodule Dialectic.Responses.LlmInterface do
  alias Dialectic.Responses.RequestQueue

  def gen_response(node, child, graph_id, live_view_topic, mode \\ nil) do
    context = GraphManager.build_context(graph_id, node)

    qn = """
    Context:
    #{context}

    Task: Teach a first‑time learner aiming for a university‑level understanding of: "#{node.content}"

    Output (markdown):
    ## [Short, descriptive title]
    - Short answer (2–3 sentences) giving the core idea and why it matters.

    ### Deep dive
    - Foundations (optional): 1 short paragraph defining key terms and assumptions.
    - Core explanation (freeform): 1–2 short paragraphs weaving the main mechanism and intuition.

    - Nuances: 2–3 bullets on pitfalls, edge cases, or common confusions; include one contrast with a neighboring idea.

    ### Next steps
    - Next questions to explore (1–2).

    Constraints: Aim for depth over breadth; ~220–320 words.
    """

    ask_model(qn, child, graph_id, live_view_topic, mode)
  end

  def gen_selection_response(node, child, graph_id, selection, live_view_topic, mode \\ nil) do
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

    ### Next steps
    - Follow‑up questions (1–2).

    Constraints: ~180–260 words.
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

    ask_model(qn, child, graph_id, live_view_topic, mode)
  end

  def gen_synthesis(n1, n2, child, graph_id, live_view_topic, mode \\ nil) do
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
      - Narrative analysis: 1–2 short paragraphs integrating common ground and the key tensions; make explicit the assumptions driving disagreement.
      - Bridge or delineation: 1 short paragraph proposing a synthesis or clarifying scope; add a testable prediction if helpful.
      - When each view is stronger and remaining trade‑offs: 2–3 concise bullets.

      ### Next steps
      - One concrete next step to test or explore.

      Constraints: ~220–320 words. If reconciliation is not possible, state the trade‑offs clearly.
      """

    ask_model(qn, child, graph_id, live_view_topic, mode)
  end

  def gen_thesis(node, child, graph_id, live_view_topic, mode \\ nil) do
    context = GraphManager.build_context(graph_id, node)

    qn = """
    Context:
    #{context}

    Write a short, beginner-friendly but rigorous argument in support of: "#{node.content}"

    Output (markdown):
    ## [Title of the pro argument]
    - Claim (1 sentence).
    - Narrative reasoning (freeform): 1–2 short paragraphs weaving mechanism and intuition.
    - Illustrative example or evidence (1–2 lines).
    - Assumptions and limits (1 line) plus a falsifiable prediction.
    - When this holds vs. when it might not (1 line).

    Constraints: 150–200 words.
    """

    ask_model(qn, child, graph_id, live_view_topic, mode)
  end

  def gen_antithesis(node, child, graph_id, live_view_topic, mode \\ nil) do
    context = GraphManager.build_context(graph_id, node)

    qn = """
    Context:
    #{context}

    Write a short, beginner-friendly but rigorous argument against: "#{node.content}"
    Steelman the opposing view (represent the strongest version fairly).

    Output (markdown):
    ## [Title of the con argument]
    - Central critique (1 sentence).
    - Narrative reasoning (freeform): 1–2 short paragraphs laying out the critique.
    - Illustrative counterexample or evidence (1–2 lines).
    - Scope and limits (1 line) plus a falsifiable prediction that would weaken this critique.
    - When this criticism applies vs. when it might not (1 line).

    Constraints: 150–200 words.
    """

    ask_model(qn, child, graph_id, live_view_topic, mode)
  end

  def gen_related_ideas(node, child, graph_id, live_view_topic, mode \\ nil) do
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

    ask_model(qn, child, graph_id, live_view_topic, mode)
  end

  def gen_deepdive(node, child, graph_id, live_view_topic, mode \\ nil) do
    context = to_string(node.content || "")

    qn = """
    Context:
    #{context}

    Task: Produce a rigorous, detailed deep dive into "#{node.content}" for an advanced learner progressing toward research-level understanding.

    Output (markdown):
    ## [Precise title]
    - One-sentence statement of what the concept is and when it applies.

    ### Deep dive
    - Core explanation (freeform): 1–2 short paragraphs tracing the main mechanism, key assumptions, and when it applies.

    - Optional nuance: 1–2 bullets on caveats or edge cases, only if it clarifies usage.

    Constraints: Aim for clarity and concision; ~280–420 words.
    """

    ask_model(qn, child, graph_id, live_view_topic, mode)
  end

  def ask_model(question, to_node, graph_id, live_view_topic) do
    ask_model(question, to_node, graph_id, live_view_topic, nil)
  end

  def ask_model(question, to_node, graph_id, live_view_topic, mode) do
    prompt =
      Dialectic.Responses.Modes.compose(
        question,
        mode || Dialectic.Responses.Modes.default()
      )

    RequestQueue.add(
      prompt,
      to_node,
      graph_id,
      live_view_topic
    )
  end
end
