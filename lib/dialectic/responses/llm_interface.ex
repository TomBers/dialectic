defmodule Dialectic.Responses.LlmInterface do
  alias Dialectic.Models.DeepSeekAPI
  # alias Dialectic.Models.Claude

  @model Application.compile_env(:dialectic, :model_to_use, "local")

  def add_question(data, n, pid) do
    IO.inspect("Sending back Data")
    :timer.sleep(2000)
    send(pid, {:steam_chunk, data, :node_id, n.id})
  end

  def gen_response(user_qn, parent, child, pid) do
    qn = "#{parent.content} \n #{user_qn}"
    # IO.inspect(qn, label: "GenResponse")
    ask_model(qn, child, pid)
  end

  def gen_synthesis(n1, n2, child, pid) do
    qn =
      """
      Please produce a synthesis of #{n1.content} & #{n2.content}
      """

    ask_model(qn, child, pid)
  end

  def gen_thesis(n, child, pid) do
    qn = """
    Please write a short argument in support of #{n.content}
    """

    ask_model(qn, child, pid)
  end

  def gen_antithesis(n, child, pid) do
    qn = """
    Please write a short argument against #{n.content}
    """

    ask_model(qn, child, pid)
  end

  def ask_model(question, to_node, pid) do
    case @model do
      "deepseek" -> DeepSeekAPI.ask(question, to_node, pid)
      # "claude" -> Claude.ask(question)
      _ -> add_question(question, to_node, pid)
    end
  end
end
