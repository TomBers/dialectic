defmodule Dialectic.Models.DeepSeekAPI do
  # Replace with your actual API key
  @api_key System.get_env("DEEPSEEK_API_KEY")
  # Replace with the actual DeepSeek API base URL
  @base_url "https://api.deepseek.com"
  @model "deepseek-chat"

  def ask(question, node_id, pid) do
    # IO.inspect(@api_key, label: "API Key")
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

    spawn(fn ->
      Req.post(url,
        headers: [{"Authorization", "Bearer #{@api_key}"}, {"Content-Type", "application/json"}],
        body: body,
        into: fn {:data, data}, context ->
          Enum.each(parse(data), fn data -> send_chunk(data, pid, node_id) end)
          {:cont, context}
        end,
        connect_options: [timeout: 30_000],
        # How long to wait to receive the response once connected
        receive_timeout: 30_000
      )
    end)

    ""
  end

  defp send_chunk(
         %{
           "choices" => [
             %{
               "delta" => %{"content" => data}
             }
           ]
         },
         pid,
         node_id
       ) do
    send(pid, {:steam_chunk, data, :node_id, node_id})
  end

  defp parse(chunk) do
    chunk
    |> String.split("data: ")
    |> Enum.map(&String.trim/1)
    |> Enum.map(&decode/1)
    |> Enum.reject(&is_nil/1)
  end

  defp decode(""), do: nil
  defp decode("[DONE]"), do: nil
  defp decode(data), do: Jason.decode!(data)
end
