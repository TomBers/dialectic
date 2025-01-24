defmodule Dialectic.Responses.LlmInterface do
  @api_url "https://api.anthropic.com/v1/messages"
  @model "claude-3-sonnet-20240229"

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

  defp call_model(prompt) do
    Req.post!(@api_url,
      json: %{
        "model" => @model,
        "max_tokens" => 1024,
        "messages" => [%{"role" => "user", "content" => prompt}]
      },
      headers: [
        {"x-api-key", System.get_env("ANTHROPIC_API_KEY")},
        {"anthropic-version", "2023-06-01"}
      ]
    ).body["content"][0]["text"]
  rescue
    error -> {:error, "API call failed: #{inspect(error)}"}
  end
end
