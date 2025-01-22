defmodule Dialectic.Responses.LlmInterface do
  def gen_response(answer) do
    """
    <p>#{answer}</p>
    """
  end

  def gen_synthesis(n1, n2) do
    """
    <p>Synthesis: #{n1.proposition} & #{n2.proposition}</p>
    """
  end

  def gen_thesis(n) do
    """
    <p>Theis: #{n.proposition}</p>
    """
  end

  def gen_antithesis(n) do
    """
    <p>Antithesis: #{n.proposition}</p>
    """
  end
end
