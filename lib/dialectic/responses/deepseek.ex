defmodule Dialectic.Models.DeepSeekAPI do
  # Replace with your actual API key
  @api_key System.get_env("DEEPSEEK_API_KEY")
  # Replace with the actual DeepSeek API base URL
  @base_url "https://api.deepseek.com"
  @model "deepseek-chat"

  def ask(question) do
    IO.inspect(@api_key, label: "API Key")
    # Replace with the correct endpoint for asking questions
    url = "#{@base_url}/chat/completions"

    body =
      Jason.encode!(%{
        model: @model,
        stream: true,
        messages: [
          %{role: "system", content: "You are a helpful assistant."},
          %{role: "user", content: question}
        ]
      })

    Req.post(url,
      headers: [{"Authorization", "Bearer #{@api_key}"}, {"Content-Type", "application/json"}],
      body: body,
      into: &StreamParser.process_stream/2,
      connect_options: [timeout: 30_000],
      # How long to wait to receive the response once connected
      receive_timeout: 30_000
    )
  end
end
