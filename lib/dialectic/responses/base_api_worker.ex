defmodule Dialectic.Workers.BaseAPIWorker do
  @moduledoc """
  A generic API worker which delegates model-specific behavior via callbacks.
  """

  use Oban.Worker, queue: :api_request, max_attempts: 5
  require Logger
  @timeout 30_000

  @callback api_key() :: String.t() | nil
  @callback request_url() :: String.t()
  @callback headers(String.t()) :: list()
  @callback build_request_body(String.t()) :: map()
  @callback parse_chunk(String.t()) :: {:ok, list()} | {:error, String.t()}
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
        {:ok, module.request_url()}
    end
  end

  defp do_request(module, url, body, graph, to_node) do
    options = [
      headers: module.headers(module.api_key()),
      body: body,
      into: &handle_stream_chunk(module, &1, &2, graph, to_node),
      connect_options: [timeout: @timeout],
      receive_timeout: @timeout
    ]

    case Req.post(url, options) do
      {:ok, response} ->
        Logger.info("Request completed successfully")

        Phoenix.PubSub.broadcast(
          Dialectic.PubSub,
          graph,
          {:llm_request_complete, to_node}
        )

        Logger.info(response)
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
    case module.parse_chunk(data) do
      {:ok, chunks} ->
        Logger.info("Parsed chunks: #{inspect(chunks)}")

        Enum.each(chunks, fn chunk ->
          module.handle_result(chunk, graph, to_node)
        end)

        {:cont, context}

      {:error, reason} ->
        Logger.info("Failed to parse chunk: #{inspect(reason)}")
        Logger.error("Failed to parse chunk: #{inspect(reason)}")
        {:cont, context}
    end
  end
end
