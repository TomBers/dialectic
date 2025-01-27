defmodule Dialectic.Responses.Claude do
  @api_url "https://api.anthropic.com/v1/messages"
  @model "claude-3-sonnet-20240229"

  def ask(prompt) do
    call_model(prompt)
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
