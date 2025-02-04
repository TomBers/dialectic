defmodule Dialectic.Models.DeepSeekAPI do
  require Logger

  @api_key System.get_env("DEEPSEEK_API_KEY")
  @base_url "https://api.deepseek.com"
  @model "deepseek-chat"
  @timeout 30_000

  def ask(question, to_node, pid) when is_binary(question) do
    with {:ok, body} <- build_request_body(question),
         {:ok, url} <- build_url() do
      spawn_request(url, body, pid, to_node)
      ""
    else
      {:error, reason} ->
        Logger.error("Failed to initiate DeepSeek request: #{inspect(reason)}")
        {:error, "Failed to process request"}
    end
  end

  def ask(_question, _to_node, _pid) do
    Logger.error("Invalid question format provided")
    {:error, "Invalid input format"}
  end

  defp build_request_body(question) do
    try do
      body = %{
        model: @model,
        stream: true,
        messages: [
          %{
            role: "system",
            content:
              "You are an expert philosopher, helping the user better understand key philosophical points. Please keep your answers concise and to the point."
          },
          %{role: "user", content: question}
        ]
      }

      {:ok, Jason.encode!(body)}
    rescue
      e ->
        Logger.error("Failed to encode request body: #{inspect(e)}")
        {:error, "Failed to encode request"}
    end
  end

  defp build_url do
    case @api_key do
      nil ->
        Logger.error("DeepSeek API key not configured")
        {:error, "API key not configured"}

      _ ->
        {:ok, "#{@base_url}/chat/completions"}
    end
  end

  defp spawn_request(url, body, pid, to_node) do
    spawn(fn ->
      headers = [
        {"Authorization", "Bearer #{@api_key}"},
        {"Content-Type", "application/json"}
      ]

      options = [
        headers: headers,
        body: body,
        into: &handle_stream_chunk(&1, &2, pid, to_node),
        connect_options: [timeout: @timeout],
        receive_timeout: @timeout
      ]

      case Req.post(url, options) do
        {:ok, _response} ->
          Logger.info("Request completed successfully")

        # send(pid, {:stream_complete, :node_id, to_node.id})

        {:error, reason} ->
          Logger.error("Request failed: #{inspect(reason)}")
          # TODO - Handle error - add retry logic??
          # send(pid, {:stream_error, "Request failed", :node_id, to_node.id})
      end
    end)
  end

  defp handle_stream_chunk({:data, data}, context, pid, to_node) do
    case parse(data) do
      {:ok, chunks} ->
        Enum.each(chunks, &send_chunk(&1, pid, to_node))
        {:cont, context}

      {:error, reason} ->
        Logger.warn("Failed to parse chunk: #{inspect(reason)}")
        {:cont, context}
    end
  end

  defp parse(chunk) do
    try do
      chunks =
        chunk
        |> String.split("data: ")
        |> Enum.map(&String.trim/1)
        |> Enum.map(&decode/1)
        |> Enum.reject(&is_nil/1)

      {:ok, chunks}
    rescue
      e ->
        Logger.error("Error parsing chunk: #{inspect(e)}")
        {:error, "Failed to parse chunk"}
    end
  end

  defp decode(""), do: nil
  defp decode("[DONE]"), do: nil

  defp decode(data) do
    try do
      Jason.decode!(data)
    rescue
      _ -> nil
    end
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
         to_node
       )
       when is_binary(data) do
    send(pid, {:steam_chunk, data, :node_id, to_node.id})
  end

  defp send_chunk(_invalid_chunk, _pid, _to_node), do: nil
end
