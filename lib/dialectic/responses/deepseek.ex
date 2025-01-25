defmodule DeepSeekAPI do
  # Replace with your actual API key
  @api_key "your_deepseek_api_key"
  # Replace with the actual DeepSeek API base URL
  @base_url "https://api.deepseek.com/v1"

  def ask(question) do
    # Replace with the correct endpoint for asking questions
    url = "#{@base_url}/ask"

    Req.post(url,
      headers: [{"Authorization", "Bearer #{@api_key}"}, {"Content-Type", "application/json"}],
      body: Jason.encode!(%{question: question})
    )
    |> handle_response()
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
