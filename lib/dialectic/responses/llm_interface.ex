defmodule Dialectic.Responses.LlmInterface do
  alias Dialectic.Responses.RequestQueue

  def gen_response(node, child, graph_id) do
    parents = Enum.reduce(node.parents, "", fn parent, acc -> acc <> parent.content <> "\n" end)
    qn = parents <> node.content
    # IO.inspect(qn, label: "GenResponse qn")
    ask_model(qn, child, graph_id)
  end

  def gen_synthesis(n1, n2, child, graph_id) do
    qn =
      """
      Please produce a synthesis of #{n1.content} & #{n2.content}
      """

    ask_model(qn, child, graph_id)
  end

  def gen_thesis(n, child, graph_id) do
    qn = """
    Please write a short argument in support of #{n.content}
    """

    ask_model(qn, child, graph_id)
  end

  def gen_antithesis(n, child, graph_id) do
    qn = """
    Please write a short argument against #{n.content}
    """

    ask_model(qn, child, graph_id)
  end

  def ask_model(question, to_node, graph_id) do
    RequestQueue.add(question, to_node, graph_id)
  end
end
