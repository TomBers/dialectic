defmodule Dialectic.Responses.LlmInterface do
  def gen_response(qn) do
    """
    <p>Answer to : #{qn}</p>
    """
  end

  def gen_synthesis(n1, n2) do
    """
    <p>Synthesis: #{n1.content} & #{n2.content}</p>
    """
  end

  def gen_thesis(n) do
    """
    <p>Theis: #{n.content}</p>
    """
  end

  def gen_antithesis(n) do
    """
    <p>Antithesis: #{n.content}</p>
    """
  end
end
