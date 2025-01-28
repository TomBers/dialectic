defmodule Dialectic.Responses.LlmInterface do
  alias Dialectic.Models.DeepSeekAPI
  alias Dialectic.Models.Claude

  @model Application.compile_env(:dialectic, :model_to_use, "local")

  def gen_response(user_qn, parent, child_id, pid) do
    qn = "#{parent.content} \n #{user_qn}"
    IO.inspect(qn, label: "GenResponse")
    ask_model(qn, child_id, pid)
  end

  def gen_synthesis(n1, n2, n3_id, pid) do
    qn =
      """
      Please produce a synthesis of #{n1.content} & #{n2.content}
      """

    ask_model(qn, n3_id, pid)
  end

  def gen_thesis(n, pid) do
    qn = """
    Please write a short argument in support of #{n.content}
    """

    ask_model(qn, n.id, pid)
  end

  def gen_antithesis(n, pid) do
    qn = """
    Please write a short argument against #{n.content}
    """

    ask_model(qn, n.id, pid)
  end

  def ask_model(question, node_id, pid) do
    case @model do
      "deepseek" -> DeepSeekAPI.ask(question, node_id, pid)
      # "claude" -> Claude.ask(question)
      _ -> question
    end
  end
end
