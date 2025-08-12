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
    module = resolve_worker_module(worker_module)

    case module do
      nil ->
        Logger.error("Unknown or unsupported worker module: #{inspect(worker_module)}")
        {:error, "Unknown or unsupported worker module"}

      _ ->
        api_key = module.api_key()

        with {:ok, body} <- build_request_body_encoded(module, question),
             {:ok, url} <- build_url(module, api_key) do
          do_request(module, url, api_key, body, graph, to_node, live_view_topic)
          :ok
        else
          {:error, reason} ->
            Logger.error("Failed to initiate API request: #{inspect(reason)}")
            {:error, reason}
        end
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

  defp build_url(module, api_key) do
    case api_key do
      nil ->
        Logger.error("API key not configured")
        {:error, "API key not configured"}

      _ ->
        # Use passed module
        {:ok, module.request_url()}
    end
  end

  defp do_request(module, url, api_key, body, graph, to_node, live_view_topic) do
    options = [
      headers: module.headers(api_key),
      body: body,
      into: &handle_stream_chunk(module, &1, &2, graph, to_node, live_view_topic),
      receive_timeout: @timeout
    ]

    client = Req.new(finch: Dialectic.Finch)

    # Broadcast that the request has started
    Phoenix.PubSub.broadcast(
      Dialectic.PubSub,
      live_view_topic,
      {:llm_request_started, to_node}
    )

    case Req.post(client, Keyword.put(options, :url, url)) do
      {:ok, %Req.Response{} = response} ->
        status = Map.get(response, :status)
        Logger.debug("HTTP response status: #{inspect(status)}")

        # Broadcast HTTP status to LiveView
        Phoenix.PubSub.broadcast(
          Dialectic.PubSub,
          live_view_topic,
          {:llm_request_http_status, to_node, status}
        )

        if status && status >= 200 && status < 300 do
          Logger.debug("Request completed successfully")

          Phoenix.PubSub.broadcast(
            Dialectic.PubSub,
            live_view_topic,
            {:llm_request_complete, to_node}
          )

          Logger.debug(response)
          :ok
        else
          # Non-2xx status: broadcast a user-facing error
          body_str =
            case response.body do
              "" -> ""
              bin when is_binary(bin) -> " Body: #{bin}"
              other -> " Body: #{inspect(other)}"
            end

          msg = "API request failed with status #{inspect(status)}." <> body_str
          Logger.error(msg)

          Phoenix.PubSub.broadcast(
            Dialectic.PubSub,
            live_view_topic,
            {:stream_error, msg, :node_id, to_node}
          )

          # Ensure the request is marked as complete
          Phoenix.PubSub.broadcast(
            Dialectic.PubSub,
            live_view_topic,
            {:llm_request_complete, to_node}
          )

          :ok
        end

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

  defp init_stream_context(context) do
    case context do
      %{buf: _} = ctx -> ctx
      bin when is_binary(bin) -> %{buf: [bin], status: nil, headers: nil}
      list when is_list(list) -> %{buf: list, status: nil, headers: nil}
      _ -> %{buf: [], status: nil, headers: nil}
    end
  end

  defp handle_stream_chunk(
         _module,
         {:status, status},
         context,
         _graph,
         _to_node,
         _live_view_topic
       ) do
    ctx = init_stream_context(context)
    {:cont, %{ctx | status: status}}
  end

  defp handle_stream_chunk(
         _module,
         {:headers, headers},
         context,
         _graph,
         _to_node,
         _live_view_topic
       ) do
    ctx = init_stream_context(context)
    {:cont, %{ctx | headers: headers}}
  end

  defp handle_stream_chunk(module, {:data, data}, context, graph, to_node, live_view_topic) do
    ctx = init_stream_context(context)

    case module.parse_chunk(data) do
      {:ok, chunks} ->
        Logger.debug("Parsed chunks: #{inspect(chunks)}")

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

        # Accumulate raw body data for the final response
        {:cont, %{ctx | buf: [data | ctx.buf]}}

      {:error, reason} ->
        Logger.debug("Failed to parse chunk: #{inspect(reason)}")
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

        # Still accumulate the raw data to help with debugging/visibility
        {:cont, %{ctx | buf: [data | ctx.buf]}}
    end
  end

  defp handle_stream_chunk(_module, :done, context, _graph, _to_node, _live_view_topic) do
    ctx = init_stream_context(context)
    body = IO.iodata_to_binary(Enum.reverse(ctx.buf))
    {:cont, body}
  end

  defp handle_stream_chunk(_module, _other, context, _graph, _to_node, _live_view_topic) do
    {:cont, context}
  end

  defp resolve_worker_module("Elixir.Dialectic.Workers.OpenAIWorker"),
    do: Dialectic.Workers.OpenAIWorker

  defp resolve_worker_module("Elixir.Dialectic.Workers.ClaudeWorker"),
    do: Dialectic.Workers.ClaudeWorker

  defp resolve_worker_module("Elixir.Dialectic.Workers.GeminiWorker"),
    do: Dialectic.Workers.GeminiWorker

  defp resolve_worker_module("Elixir.Dialectic.Workers.DeepSeekWorker"),
    do: Dialectic.Workers.DeepSeekWorker

  defp resolve_worker_module("Elixir.Dialectic.Workers.LocalWorker"),
    do: Dialectic.Workers.LocalWorker

  defp resolve_worker_module(module) when is_atom(module), do: module
  defp resolve_worker_module(_), do: nil
end
