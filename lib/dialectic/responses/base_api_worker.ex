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
  @callback handle_result(map(), graph_id :: any(), to_node :: any(), live_view_topic :: any()) ::
              any()

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{
          "question" => question,
          "to_node" => to_node,
          "graph" => graph,
          "module" => worker_module,
          "live_view_topic" => live_view_topic
        }
      }) do
    # Get the implementing module from args
    module = String.to_existing_atom(worker_module)

    with {:ok, body} <- build_request_body_encoded(module, question),
         {:ok, url} <- build_url(module) do
      do_request(module, url, body, graph, to_node, live_view_topic)
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

  defp do_request(module, url, body, graph, to_node, live_view_topic) do
    options = [
      headers: module.headers(module.api_key()),
      body: body,
      into: &handle_stream_chunk(module, &1, &2, graph, to_node, live_view_topic),
      connect_options: [timeout: @timeout],
      receive_timeout: @timeout
    ]

    case Req.post(url, options) do
      {:ok, response} ->
        Logger.info("Request completed successfully")

        Phoenix.PubSub.broadcast(
          Dialectic.PubSub,
          live_view_topic,
          {:llm_request_complete, to_node}
        )

        Logger.info(response)
        :ok

      {:error, reason} ->
        Logger.error("Request failed: #{inspect(reason)}")

        # Broadcast the error to LiveView
        Phoenix.PubSub.broadcast(
          Dialectic.PubSub,
          live_view_topic,
          {:stream_error, "API request failed: #{inspect(reason)}", :node_id, to_node}
        )

        # Ensure the request is marked as complete even when it fails
        Phoenix.PubSub.broadcast(
          Dialectic.PubSub,
          live_view_topic,
          {:llm_request_complete, to_node}
        )

        raise "Request failed: #{inspect(reason)}"
    end
  rescue
    exception ->
      Logger.error("Exception during request: #{inspect(exception)}")

      # Broadcast the exception to LiveView
      Phoenix.PubSub.broadcast(
        Dialectic.PubSub,
        live_view_topic,
        {:stream_error, "Error during API request: #{Exception.message(exception)}", :node_id,
         to_node}
      )

      # Ensure the request is marked as complete even when it fails
      Phoenix.PubSub.broadcast(
        Dialectic.PubSub,
        live_view_topic,
        {:llm_request_complete, to_node}
      )

      raise exception
  end

  defp handle_stream_chunk(module, {:data, data}, context, graph, to_node, live_view_topic) do
    case module.parse_chunk(data) do
      {:ok, chunks} ->
        Logger.info("Parsed chunks: #{inspect(chunks)}")

        # Process each chunk with priority for the first one
        case chunks do
          [first_chunk | rest_chunks] ->
            # Process the first chunk immediately
            if Map.has_key?(first_chunk, "error") do
              Logger.error("Error in first chunk: #{inspect(first_chunk)}")
              module.handle_result(first_chunk, graph, to_node, live_view_topic)
            else
              module.handle_result(first_chunk, graph, to_node, live_view_topic)
            end

            # Process the rest of the chunks
            Enum.each(rest_chunks, fn chunk ->
              if Map.has_key?(chunk, "error") do
                Logger.error("Error in chunk: #{inspect(chunk)}")
                module.handle_result(chunk, graph, to_node, live_view_topic)
              else
                module.handle_result(chunk, graph, to_node, live_view_topic)
              end
            end)

          [] ->
            # No chunks to process
            nil
        end

        {:cont, context}

      {:error, reason} ->
        Logger.error("Failed to parse chunk: #{inspect(reason)}")

        # Broadcast parse error to LiveView
        Phoenix.PubSub.broadcast(
          Dialectic.PubSub,
          live_view_topic,
          {:stream_error, "Error processing response: #{inspect(reason)}", :node_id, to_node}
        )

        # Ensure the request is marked as complete when we can't parse the chunk
        Phoenix.PubSub.broadcast(
          Dialectic.PubSub,
          live_view_topic,
          {:llm_request_complete, to_node}
        )

        {:cont, context}
    end
  end
end
