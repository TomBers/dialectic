defmodule Dialectic.Responses.LlmInterface do
  alias Dialectic.Responses.{RequestQueue, Prompts}

  def gen_response(node, child, graph_id, live_view_topic) do
    context = GraphManager.build_context(graph_id, node)

    prompt =
      Prompts.explain(context, node.content)

    ask_model(prompt, child, graph_id, live_view_topic)
  end

  def gen_selection_response(node, child, graph_id, selection, live_view_topic) do
    context = GraphManager.build_context(graph_id, node)

    prompt =
      Prompts.selection(context, selection)

    ask_model(prompt, child, graph_id, live_view_topic)
  end

  def gen_synthesis(n1, n2, child, graph_id, live_view_topic) do
    # TODO - Add n2 context ?? need to enforce limit??
    context1 = GraphManager.build_context(graph_id, n1)
    context2 = GraphManager.build_context(graph_id, n2)

    prompt =
      Prompts.synthesis(context1, context2, n1.content, n2.content)

    ask_model(prompt, child, graph_id, live_view_topic)
  end

  def gen_thesis(node, child, graph_id, live_view_topic) do
    context = GraphManager.build_context(graph_id, node)

    prompt =
      Prompts.thesis(context, node.content)

    ask_model(prompt, child, graph_id, live_view_topic)
  end

  def gen_antithesis(node, child, graph_id, live_view_topic) do
    context = GraphManager.build_context(graph_id, node)

    prompt =
      Prompts.antithesis(context, node.content)

    ask_model(prompt, child, graph_id, live_view_topic)
  end

  def gen_related_ideas(node, child, graph_id, live_view_topic) do
    context = GraphManager.build_context(graph_id, node)

    content =
      node
      |> case do
        nil -> ""
        n -> to_string(n.content || "")
      end

    title = Prompts.extract_title(content)

    prompt =
      Prompts.related_ideas(context, title)

    ask_model(prompt, child, graph_id, live_view_topic)
  end

  def gen_deepdive(node, child, graph_id, live_view_topic) do
    context = to_string(node.content || "")

    prompt =
      Prompts.deep_dive(context, node.content)

    ask_model(prompt, child, graph_id, live_view_topic)
  end

  def ask_model(question, to_node, graph_id, live_view_topic) do
    RequestQueue.add(
      question,
      to_node,
      graph_id,
      live_view_topic
    )
  end
end
