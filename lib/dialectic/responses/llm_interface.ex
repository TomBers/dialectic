defmodule Dialectic.Responses.LlmInterface do
  alias Dialectic.Responses.RequestQueue

  def gen_response(node, child, graph_id, live_view_topic, mode \\ nil) do
    context = GraphManager.build_context(graph_id, node)

    qn = """
    Context:
    #{context}

    Instruction:
    Respond to the user's request — "#{node.content}" — with a clear answer guided by the selected mode's style. Provide a single H2 title, use concise paragraphs, and only add bullets if they improve clarity.
    """

    ask_model(qn, child, graph_id, live_view_topic, mode)
  end

  def gen_selection_response(node, child, graph_id, selection, live_view_topic, mode \\ nil) do
    context = GraphManager.build_context(graph_id, node)

    default_schema = """
    Instruction:
    Paraphrase the selection succinctly and explain its significance for the current context. Provide a single H2 title; use compact paragraphs and only add bullets when they clarify claims, assumptions, implications, or limitations.
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
      """ <> if add_default?, do: "\n\n" <> default_schema, else: ""

    ask_model(qn, child, graph_id, live_view_topic, mode)
  end

  def gen_synthesis(n1, n2, child, graph_id, live_view_topic, mode \\ nil) do
    context1 = GraphManager.build_context(graph_id, n1)
    context2 = GraphManager.build_context(graph_id, n2)

    qn =
      """
      Context of first argument:
      #{context1}

      Context of second argument:
      #{context2}

      Instruction:
      Synthesize the positions in "#{n1.content}" and "#{n2.content}" by identifying common ground and key tensions, then propose either a synthesis or a clear delineation of scope. Provide a single H2 title and concise paragraphs; add brief bullets only if they help highlight trade‑offs.
      """

    ask_model(qn, child, graph_id, live_view_topic, mode)
  end

  def gen_thesis(node, child, graph_id, live_view_topic, mode \\ nil) do
    context = GraphManager.build_context(graph_id, node)

    qn = """
    Context:
    #{context}

    Instruction:
    Write a short, beginner‑friendly but rigorous argument supporting "#{node.content}". Provide a single H2 title, a clear claim and compact reasoning; add one concise example if helpful.
    """

    ask_model(qn, child, graph_id, live_view_topic, mode)
  end

  def gen_antithesis(node, child, graph_id, live_view_topic, mode \\ nil) do
    context = GraphManager.build_context(graph_id, node)

    qn = """
    Context:
    #{context}

    Instruction:
    Write a short, beginner‑friendly but rigorous critique of "#{node.content}". Steelman the opposing view, state the central critique clearly, and support it with compact reasoning and, if useful, a concise counterexample.
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

    Instruction:
    Suggest a diverse set of related but distinct concepts to explore next for "#{title}". Provide a single H2 title and a concise bullet list (no subsections). Each bullet: concept — a one‑sentence rationale or contrast.
    """

    ask_model(qn, child, graph_id, live_view_topic, mode)
  end

  def gen_deepdive(node, child, graph_id, live_view_topic, mode \\ nil) do
    context = to_string(node.content || "")

    qn = """
    Context:
    #{context}

    Instruction:
    Provide a rigorous explanation of "#{node.content}" aimed at an advanced learner, naming key assumptions and scope. Use 2–4 compact paragraphs, adding brief caveats only if they clarify. Provide a single H2 title.
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
