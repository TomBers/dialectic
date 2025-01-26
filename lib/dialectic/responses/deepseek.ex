defmodule DeepSeekAPI do
  # Replace with your actual API key
  @api_key System.get_env("DEEPSEEK_API_KEY")
  # Replace with the actual DeepSeek API base URL
  @base_url "https://api.deepseek.com"
  @model "deepseek-chat"

  def ask(question) do
    IO.inspect(@api_key, label: "API Key")
    # Replace with the correct endpoint for asking questions
    url = "#{@base_url}/chat/completions"

    Req.post(url,
      headers: [{"Authorization", "Bearer #{@api_key}"}, {"Content-Type", "application/json"}],
      body:
        Jason.encode!(%{
          model: @model,
          stream: false,
          messages: [
            %{role: "system", content: "You are a helpful assistant."},
            %{role: "user", content: question}
          ]
        })
    )
    |> handle_response()
    |> extract_content()
  end

  defp extract_content({:ok, body}) do
    Map.get(body, "choices") |> hd() |> Map.get("message") |> Map.get("content")
  end

  defp handle_response({:ok, %{status: status, body: body}}) when status in 200..299 do
    {:ok, body}
  end

  defp handle_response({:ok, %{status: status, body: body}}) do
    {:error, "API request failed with status #{status}: #{inspect(body)}"}
  end

  defp handle_response({:error, reason}) do
    {:error, "API request failed: #{inspect(reason)}"}
  end
end
