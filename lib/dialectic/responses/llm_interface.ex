defmodule Dialectic.Responses.LlmInterface do
  alias Dialectic.Models.DeepSeekAPI
  alias Dialectic.Models.Claude

  @model Application.compile_env(:dialectic, :model_to_use, "local")

  def gen_response(user_qn, node) do
    qn = "#{node.content} \n #{user_qn}"
    IO.inspect(qn, label: "GenResponse")
    ask_model(qn)
  end

  def gen_synthesis(n1, n2) do
    qn =
      """
      Please produce a synthesis of #{n1.content} & #{n2.content}
      """

    ask_model(qn)
  end

  def gen_thesis(n) do
    qn = """
    Please write a short argument in support of #{n.content}
    """

    ask_model(qn)
  end

  def gen_antithesis(n) do
    qn = """
    Please write a short argument against #{n.content}
    """

    ask_model(qn)
  end

  def ask_model(question) do
    case @model do
      "deepseek" -> DeepSeekAPI.ask(question)
      "claude" -> Claude.ask(question)
      _ -> question
    end
  end
end
