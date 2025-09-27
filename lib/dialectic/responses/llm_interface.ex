defmodule Dialectic.Responses.LlmInterface do
  alias Dialectic.Responses.RequestQueue

  def gen_response(node, child, graph_id, live_view_topic) do
    context = GraphManager.build_context(graph_id, node)

    qn = """
    Context:
    #{context}

    Task: Answer the question for a first-time learner.
    Question: "#{node.content}"

    Output (markdown):
    ## [Short, descriptive title]
    - Short answer (2–3 sentences).
    - Key terms (bulleted: term — brief definition).
    - How it works (3–5 bullets).
    - Simple example (1–2 lines).
    - Pitfalls or nuances (1–3 bullets).
    - Next questions to explore (1–2).

    Constraints: ~150–220 words total.
    """

    ask_model(qn, child, graph_id, live_view_topic)
  end

  def gen_selection_response(node, child, graph_id, selection, live_view_topic) do
    context = GraphManager.build_context(graph_id, node)

    qn = """
    Context:
    #{context}

    Instruction (apply to the context and current node):
    #{selection}

    Audience: first-time learner.

    Output (markdown):
    ## [Short, descriptive title]
    - Paraphrase of the selection (1–2 sentences).
    - Key terms (term — brief definition).
    - Why it matters here (2–3 bullets).
    - Follow-up questions or next steps (1–2).
    """

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

      Task: Synthesize the positions in "#{n1.content}" and "#{n2.content}" for a first-time learner.

      Output (markdown):
      ## [Short, descriptive title]
      - Common ground (2 bullets).
      - Key tension (2 bullets).
      - Bridge or synthesis idea (3 bullets).
      - Combined takeaway (1–2 sentences).
      - Trade-offs or unknowns (1–2 bullets).
      - Next step to test or explore (1).

      Constraints: ~150–220 words. If reconciliation is not possible, state the trade-offs clearly.
      """

    ask_model(qn, child, graph_id, live_view_topic)
  end

  def gen_thesis(node, child, graph_id, live_view_topic) do
    context = GraphManager.build_context(graph_id, node)

    qn = """
    Context:
    #{context}

    Write a short, beginner-friendly argument in support of: "#{node.content}"

    Output (markdown):
    ## [Title of the pro argument]
    - Claim: [1 sentence].
    - Reasons (3 bullets).
    - Example or evidence (1 line).
    - Caveat or limits (1 line).
    - When this holds vs. when it might not (1 line).

    Constraints: 120–150 words. Define any jargon.
    """

    ask_model(qn, child, graph_id, live_view_topic)
  end

  def gen_antithesis(node, child, graph_id, live_view_topic) do
    context = GraphManager.build_context(graph_id, node)

    qn = """
    Context:
    #{context}

    Write a short, beginner-friendly argument against: "#{node.content}"
    Steelman the opposing view (represent the strongest version fairly).

    Output (markdown):
    ## [Title of the con argument]
    - Claim: [1 sentence].
    - Reasons (3 bullets).
    - Example or evidence (1 line).
    - Caveat or limits (1 line).
    - When this criticism applies vs. when it might not (1 line).

    Constraints: 120–150 words. Define any jargon.
    """

    ask_model(qn, child, graph_id, live_view_topic)
  end

  def ask_model(question, to_node, graph_id, live_view_topic) do
    style = """
    You are explaining to a curious beginner.
    - Use plain language; define jargon briefly.
    - Prefer short paragraphs and bullet lists.
    - If context is insufficient, say what’s missing and ask one clarifying question.
    - Prefer info from the provided Context; label other info as "Background".
    - Never fabricate citations or data; if uncertain, say "not enough context."
    Always output markdown and begin with an H2 title (## …).
    """

    RequestQueue.add(
      style <> "\n\n" <> question,
      to_node,
      graph_id,
      live_view_topic
    )
  end
end
