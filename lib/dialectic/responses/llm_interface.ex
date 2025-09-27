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
    - Further reading / references (1–3 items: Title — Source (URL) or a short search query if uncertain).

    Constraints: ~150–220 words total (excluding references).
    """

    ask_model(qn, child, graph_id, live_view_topic)
  end

  def gen_selection_response(node, child, graph_id, selection, live_view_topic) do
    context = GraphManager.build_context(graph_id, node)

    default_schema = """
    Output (markdown):
    ## [Short, descriptive title]
    - Paraphrase of the selection (1–2 sentences).
    - Key terms (term — brief definition).
    - Why it matters here (2–3 bullets).
    - Follow-up questions or next steps (1–2).
    - Further reading / references (1–2 items: Title — Source (URL) or a short search query if uncertain).
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

      Audience: first-time learner.
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

      Task: Synthesize the positions in "#{n1.content}" and "#{n2.content}" for a first-time learner.

      Output (markdown):
      ## [Short, descriptive title]
      - Common ground (2 bullets).
      - Key tension (2 bullets).
      - Bridge or synthesis idea (3 bullets).
      - Combined takeaway (1–2 sentences).
      - Trade-offs or unknowns (1–2 bullets).
      - Next step to test or explore (1).
      - Further reading / references (1–3 items: Title — Source (URL) or a short search query if uncertain).

      Constraints: ~150–220 words (excluding references). If reconciliation is not possible, state the trade-offs clearly.
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
    - Further reading / references (1–2 items: Title — Source (URL) or a short search query if uncertain).

    Constraints: 120–150 words (excluding references). Define any jargon.
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
    - Further reading / references (1–2 items: Title — Source (URL) or a short search query if uncertain).

    Constraints: 120–150 words (excluding references). Define any jargon.
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
    - Each bullet: Concept — 1 sentence on why it’s relevant and how it differs from the current idea.
    - Use plain language and avoid jargon.

    Return only the headings and bullets; no intro or outro.
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
    - Never fabricate citations or data. Only include references you are confident in; prefer official docs, textbooks, or peer‑reviewed/authoritative sources. If unsure, provide a concise search query instead of a link and say what’s uncertain.
    - When a schema includes "Further reading / references", provide 1–3 trustworthy items formatted as: Title — Source (URL). Keep them short.
    Default to markdown and an H2 title (## …) unless the instruction specifies a different format. When there is any conflict, follow the question/selection’s format and instructions.
    """

    RequestQueue.add(
      style <> "\n\n" <> question,
      to_node,
      graph_id,
      live_view_topic
    )
  end
end
