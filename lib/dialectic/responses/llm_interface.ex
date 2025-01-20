defmodule Dialectic.Responses.LlmInterface do
  def gen_response(answer) do
    """
    <p>#{answer}</p>
    """
  end
end
