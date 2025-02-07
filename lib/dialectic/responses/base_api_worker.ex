defmodule Dialectic.Workers.BaseAPIWorker do
  @moduledoc """
  A generic API worker which delegates model-specific behavior via callbacks.
  """
  use Oban.Worker, queue: :api_request, max_attempts: 5
  require Logger
  @timeout 30_000

  @callback api_key() :: String.t() | nil
  @callback base_url() :: String.t()
  @callback request_path() :: String.t()
  @callback build_request_body(String.t()) :: map()
  @callback handle_result(map(), graph_id :: any(), to_node :: any()) :: any()

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{
          "question" => question,
          "to_node" => to_node,
          "graph" => graph,
          "module" => worker_module
        }
      }) do
    # Get the implementing module from args
    module = String.to_existing_atom(worker_module)

    with {:ok, body} <- build_request_body_encoded(module, question),
         {:ok, url} <- build_url(module) do
      do_request(module, url, body, graph, to_node)
      :ok
    else
      {:error, reason} ->
        Logger.error("Failed to initiate API request: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp build_request_body_encoded(module, question) do
    try do
      # Use passed module
      body = module.build_request_body(question)
      {:ok, Jason.encode!(body)}
    rescue
      e ->
        Logger.error("Failed to encode request body: #{inspect(e)}")
        {:error, "Failed to encode request"}
    end
  end

  defp build_url(module) do
    case module.api_key() do
      nil ->
        Logger.error("API key not configured")
        {:error, "API key not configured"}

      _ ->
        # Use passed module
        {:ok, "#{module.base_url()}/#{module.request_path()}"}
    end
  end

  defp do_request(module, url, body, graph, to_node) do
    headers = [
      {"Authorization", "Bearer #{module.api_key()}"},
      {"Content-Type", "application/json"}
    ]

    options = [
      headers: headers,
      body: body,
      into: &handle_stream_chunk(module, &1, &2, graph, to_node),
      connect_options: [timeout: @timeout],
      receive_timeout: @timeout
    ]

    case Req.post(url, options) do
      {:ok, _response} ->
        Logger.info("Request completed successfully")
        :ok

      {:error, reason} ->
        Logger.error("Request failed: #{inspect(reason)}")
        raise "Request failed: #{inspect(reason)}"
    end
  rescue
    exception ->
      Logger.error("Exception during request: #{inspect(exception)}")
      raise exception
  end

  defp handle_stream_chunk(module, {:data, data}, context, graph, to_node) do
    case parse(data) do
      {:ok, chunks} ->
        Enum.each(chunks, fn chunk ->
          module.handle_result(chunk, graph, to_node)
        end)

        {:cont, context}

      {:error, reason} ->
        Logger.error("Failed to parse chunk: #{inspect(reason)}")
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
end
