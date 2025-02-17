defmodule Dialectic.Responses.LlmInterface do
  alias Dialectic.Responses.RequestQueue

  def gen_response(node, child, graph_id) do
    context = GraphManager.build_context(graph_id, node)

    qn = """
    Context: #{context} \n\n
    Question: #{node.content}
    """

    ask_model(qn, child, graph_id)
  end

  def gen_synthesis(n1, n2, child, graph_id) do
    # TODO - Add n2 context ?? need to enforce limit??
    context = GraphManager.build_context(graph_id, n1)

    qn =
      """
      Context: #{context} \n\n
      Please produce a synthesis of #{n1.content} & #{n2.content}
      """

    ask_model(qn, child, graph_id)
  end

  def gen_thesis(node, child, graph_id) do
    context = GraphManager.build_context(graph_id, node)

    qn = """
    Context: #{context} \n\n
    Please write a short argument in support of #{node.content}
    """

    ask_model(qn, child, graph_id)
  end

  def gen_antithesis(node, child, graph_id) do
    context = GraphManager.build_context(graph_id, node)

    qn = """
    Context: #{context} \n\n
    Please write a short argument against #{node.content}
    """

    ask_model(qn, child, graph_id)
  end

  def ask_model(question, to_node, graph_id) do
    RequestQueue.add(question, to_node, graph_id)
  end
end
