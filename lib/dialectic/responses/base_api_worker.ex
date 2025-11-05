defmodule Dialectic.Workers.BaseAPIWorker do
  @moduledoc """
  A generic API worker which delegates model-specific behavior via callbacks.
  """
  alias Dialectic.DbActions.DbWorker
  alias Dialectic.Responses.Utils

  use Oban.Worker, queue: :api_request, max_attempts: 5
  require Logger
  @timeout 30_000

  @callback api_key() :: String.t() | nil
  @callback request_url() :: String.t()
  @callback headers(String.t()) :: list()
  @callback build_request_body(String.t()) :: map()
  @callback extract_text(map()) :: String.t() | nil

  @callback request_options() :: Keyword.t()

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
    # Base options always included
    base_options = [
      headers: module.headers(module.api_key()),
      body: body,
      connect_options: [timeout: @timeout],
      receive_timeout: @timeout
    ]

    # Add custom request options if the module implements them, otherwise use defaults
    options =
      if function_exported?(module, :request_options, 0) do
        # Merge the options, with custom options taking precedence
        Keyword.merge(base_options, module.request_options())
      else
        base_options
      end

    case Req.post(url, options) do
      {:ok, %Req.Response{body: resp_body}} ->
        data_map =
          cond do
            is_map(resp_body) ->
              resp_body

            is_binary(resp_body) ->
              case Jason.decode(resp_body) do
                {:ok, decoded} when is_map(decoded) -> decoded
                _ -> %{}
              end

            true ->
              %{}
          end

        case module.extract_text(data_map) do
          text when is_binary(text) and byte_size(text) > 0 ->
            Utils.process_text(graph, to_node, text, module, live_view_topic)

          _ ->
            :ok
        end

        DbWorker.save_graph(graph, false)

        Phoenix.PubSub.broadcast(
          Dialectic.PubSub,
          live_view_topic,
          {:llm_request_complete, to_node}
        )

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
end
