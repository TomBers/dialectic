defmodule Dialectic.Workers.OpenAIWorker do
  alias Dialectic.Responses.Utils

  @moduledoc """
  Worker for the OpenAI Chat API.
  """
  require Logger
  use Oban.Worker, queue: :openai_request, max_attempts: 5, priority: 0

  @behaviour Dialectic.Workers.BaseAPIWorker

  @model "gpt-5-mini-2025-08-07"
  # Model-specific configuration:
  # Optimized timeout for OpenAI
  @request_timeout 20_000
  # Connection pool size
  @pool_size 20

  @impl true
  def api_key, do: System.get_env("OPENAI_API_KEY")

  @impl true
  def request_url, do: "https://api.openai.com/v1/chat/completions"

  @impl true
  def headers(api_key) do
    [
      {"Authorization", "Bearer #{api_key}"},
      {"Content-Type", "application/json"},
      {"Accept", "application/json"}
    ]
  end

  @impl true
  def request_options do
    [
      connect_options: [timeout: @request_timeout],
      receive_timeout: @request_timeout,
      pool_size: @pool_size,
      pool_timeout: 5000
    ]
  end

  @impl true
  def build_request_body(question) do
    %{
      model: @model,
      stream: true,
      messages: [
        %{
          role: "system",
          content:
            "You are an expert philosopher, helping the user better understand key philosophical points. Please keep your answers concise and to the point. Add references to sources when appropriate."
        },
        %{role: "user", content: question}
      ]
    }
  end

  @impl true
  def parse_chunk(chunk), do: Utils.parse_chunk(chunk)

  @impl true
  def handle_result(
        %{
          "choices" => [
            %{"delta" => %{"content" => data}}
          ]
        },
        graph_id,
        to_node,
        live_view_topic
      )
      when is_binary(data),
      do: Utils.process_chunk(graph_id, to_node, data, __MODULE__, live_view_topic)

  @impl true
  def handle_result(other, _graph, _to_node, _live_view_topic) do
    IO.inspect(other, label: "Error")
    :ok
  end

  @impl Oban.Worker
  def perform(
        %Oban.Job{
          args: %{
            "question" => question,
            "to_node" => to_node,
            "graph" => graph,
            "module" => _worker_module,
            "live_view_topic" => live_view_topic
          }
        } = job
      ) do
    # Fast path for OpenAI - optimized request handling
    with {:ok, body} <- build_request_body_encoded(question),
         {:ok, url} <- build_url() do
      do_optimized_request(url, body, graph, to_node, live_view_topic)
      :ok
    else
      {:error, reason} ->
        Logger.error("Failed to initiate OpenAI request: #{inspect(reason)}")
        # Fall back to the base worker implementation
        Dialectic.Workers.BaseAPIWorker.perform(job)
    end
  end

  defp build_request_body_encoded(question) do
    try do
      body = build_request_body(question)
      {:ok, Jason.encode!(body)}
    rescue
      e ->
        Logger.error("Failed to encode OpenAI request body: #{inspect(e)}")
        {:error, "Failed to encode request"}
    end
  end

  defp build_url do
    case api_key() do
      nil ->
        Logger.error("OpenAI API key not configured")
        {:error, "API key not configured"}

      _ ->
        {:ok, request_url()}
    end
  end

  defp do_optimized_request(url, body, graph, to_node, live_view_topic) do
    options =
      [
        headers: headers(api_key()),
        body: body,
        into: &handle_stream_chunk(&1, &2, graph, to_node, live_view_topic)
      ] ++ request_options()

    task =
      Task.async(fn ->
        Req.post(url, options)
      end)

    case Task.await(task, @request_timeout + 5000) do
      {:ok, _response} ->
        Logger.info("OpenAI request completed successfully")

        Phoenix.PubSub.broadcast(
          Dialectic.PubSub,
          live_view_topic,
          {:llm_request_complete, to_node}
        )

        :ok

      {:error, reason} ->
        Logger.error("OpenAI request failed: #{inspect(reason)}")
        raise "OpenAI request failed: #{inspect(reason)}"
    end
  rescue
    exception ->
      Logger.error("Exception during OpenAI request: #{inspect(exception)}")
      raise exception
  end

  defp handle_stream_chunk({:data, data}, context, graph, to_node, live_view_topic) do
    case parse_chunk(data) do
      {:ok, chunks} ->
        Enum.each(chunks, fn chunk ->
          handle_result(chunk, graph, to_node, live_view_topic)
        end)

        {:cont, context}

      {:error, reason} ->
        Logger.error("Failed to parse OpenAI chunk: #{inspect(reason)}")
        {:cont, context}
    end
  end
end
