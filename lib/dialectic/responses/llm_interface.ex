defmodule Dialectic.Responses.LlmInterface do
  alias Dialectic.Responses.RequestQueue

  def gen_response(node, child, graph_id, live_view_topic) do
    context = GraphManager.build_context(graph_id, node)

    qn = """
    Context: #{context} \n\n
    Question: #{node.content}
    """

    ask_model(qn, child, graph_id, live_view_topic)
  end

  def gen_selection_response(node, child, graph_id, selection, live_view_topic) do
    context = GraphManager.build_context(graph_id, node)

    qn = """
    Context: #{context} \n\n
    Please write a short explanation for the selection: #{selection}
    """

    ask_model(qn, child, graph_id, live_view_topic)
  end

  def gen_synthesis(n1, n2, child, graph_id, live_view_topic) do
    # TODO - Add n2 context ?? need to enforce limit??
    context1 = GraphManager.build_context(graph_id, n1)
    context2 = GraphManager.build_context(graph_id, n2)

    qn =
      """
      Context of first argument: #{context1} \n\n
      Context of second argument: #{context2} \n\n
      Please produce a synthesis of #{n1.content} & #{n2.content}
      """

    ask_model(qn, child, graph_id, live_view_topic)
  end

  def gen_thesis(node, child, graph_id, live_view_topic) do
    context = GraphManager.build_context(graph_id, node)

    qn = """
    Context: #{context} \n\n
    Please write a short argument in support of #{node.content}
    """

    ask_model(qn, child, graph_id, live_view_topic)
  end

  def gen_antithesis(node, child, graph_id, live_view_topic) do
    context = GraphManager.build_context(graph_id, node)

    qn = """
    Context: #{context} \n\n
    Please write a short argument against #{node.content}
    """

    ask_model(qn, child, graph_id, live_view_topic)
  end

  def ask_model(question, to_node, graph_id, live_view_topic) do
    RequestQueue.add(
      question <>
        "\n Make sure to add a title in the response.",
      to_node,
      graph_id,
      live_view_topic
    )
  end
end
