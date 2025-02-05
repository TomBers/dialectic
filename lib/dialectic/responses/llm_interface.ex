defmodule Dialectic.Responses.LlmInterface do
  alias Dialectic.Responses.RequestQueue

  @model Application.compile_env(:dialectic, :model_to_use, "local")

  def add_question(data, to_node, graph_id) do
    Phoenix.PubSub.broadcast(
      Dialectic.PubSub,
      graph_id,
      {:stream_chunk, data, :node_id, to_node}
    )
  end

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
    case @model do
      "deepseek" -> RequestQueue.add(question, to_node, graph_id)
      # "claude" -> Claude.ask(question)
      _ -> add_question("reply to: " <> question, to_node, graph_id)
    end
  end
end
