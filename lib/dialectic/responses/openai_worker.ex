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

  @impl true
  def api_key, do: System.get_env("OPENAI_API_KEY")

  @impl true
  def request_url, do: "https://api.openai.com/v1/chat/completions"

  @impl true
  def headers(api_key) do
    [
      {"Authorization", "Bearer #{api_key}"},
      {"Content-Type", "application/json"},
      {"Accept", "text/event-stream"}
    ]
  end

  @impl true
  def request_options do
    [
      connect_options: [timeout: @request_timeout],
      receive_timeout: @request_timeout,
      retry: :transient,
      max_retries: 2
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
      when is_binary(data) do
    result_time = DateTime.utc_now()
    Dialectic.Performance.Logger.log("OpenAI content delta received")
    result = Utils.process_chunk(graph_id, to_node, data, __MODULE__, live_view_topic)
    post_process_time = DateTime.utc_now()
    process_time_ms = DateTime.diff(post_process_time, result_time, :millisecond)
    Dialectic.Performance.Logger.log("OpenAI content processed (took #{process_time_ms}ms)")
    result
  end

  @impl true
  def handle_result(
        %{
          "choices" => [
            %{"delta" => %{}, "finish_reason" => "stop"}
          ]
        },
        _graph_id,
        _to_node,
        _live_view_topic
      ),
      do: :ok

  @impl true
  def handle_result(other, _graph, _to_node, _live_view_topic) do
    Logger.debug("Unhandled response format: #{inspect(other)}")
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
        } = _job
      ) do
    IO.inspect("Oban Worker Perform: #{DateTime.utc_now()}")
    Dialectic.Performance.Logger.log("Oban Worker Perform")
    # Fast path for OpenAI - optimized request handling
    with {:ok, body} <- build_request_body_encoded(question),
         {:ok, url} <- build_url() do
      do_optimized_request(url, body, graph, to_node, live_view_topic)
      :ok
    else
      {:error, reason} ->
        Logger.error("Failed to initiate OpenAI request: #{inspect(reason)}")
        # Return the error directly instead of falling back to base worker
        # to avoid potential infinite recursion
        {:error, reason}
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
    request_start_time = DateTime.utc_now()
    Dialectic.Performance.Logger.log("OpenAI request start")

    options = [
      headers: headers(api_key()),
      body: body,
      into: &handle_stream_chunk(&1, &2, graph, to_node, live_view_topic, request_start_time),
      receive_timeout: @request_timeout,
      retry: :transient,
      max_retries: 2,
      finch: Dialectic.Finch
    ]

    task =
      Task.async(fn ->
        Dialectic.Performance.Logger.log("OpenAI HTTP request initiated")
        Req.post(url, options)
      end)

    case Task.await(task, @request_timeout + 5000) do
      {:ok, response} ->
        request_end_time = DateTime.utc_now()
        duration_ms = DateTime.diff(request_end_time, request_start_time, :millisecond)
        Dialectic.Performance.Logger.log("OpenAI request completed (took #{duration_ms}ms)")
        Logger.info("OpenAI request completed successfully")

        Phoenix.PubSub.broadcast(
          Dialectic.PubSub,
          live_view_topic,
          {:llm_request_complete, to_node}
        )

        :ok

      {:error, reason} ->
        request_error_time = DateTime.utc_now()
        duration_ms = DateTime.diff(request_error_time, request_start_time, :millisecond)
        Dialectic.Performance.Logger.log("OpenAI request failed (after #{duration_ms}ms)")
        Logger.error("OpenAI request failed: #{inspect(reason)}")
        raise "OpenAI request failed: #{inspect(reason)}"
    end
  rescue
    exception ->
      # rescue_time = DateTime.utc_now()
      # duration_ms = DateTime.diff(rescue_time, request_start_time, :millisecond)
      # Dialectic.Performance.Logger.log("OpenAI request exception (after #{duration_ms}ms)")
      Logger.error("Exception during OpenAI request: #{inspect(exception)}")
      raise exception
  end

  defp handle_stream_chunk(
         {:data, data},
         context,
         graph,
         to_node,
         live_view_topic,
         request_start_time
       ) do
    chunk_received_time = DateTime.utc_now()
    time_since_request_ms = DateTime.diff(chunk_received_time, request_start_time, :millisecond)

    Dialectic.Performance.Logger.log(
      "OpenAI chunk received (#{time_since_request_ms}ms since request start)"
    )

    parsing_start_time = DateTime.utc_now()

    case parse_chunk(data) do
      {:ok, chunks} ->
        parsing_end_time = DateTime.utc_now()
        parsing_time_ms = DateTime.diff(parsing_end_time, parsing_start_time, :millisecond)

        Dialectic.Performance.Logger.log(
          "OpenAI chunk parsing completed (took #{parsing_time_ms}ms)"
        )

        Enum.each(chunks, fn chunk ->
          chunk_processing_start = DateTime.utc_now()
          Dialectic.Performance.Logger.log("OpenAI chunk processing start")
          handle_result(chunk, graph, to_node, live_view_topic)
          chunk_processing_end = DateTime.utc_now()

          processing_time_ms =
            DateTime.diff(chunk_processing_end, chunk_processing_start, :millisecond)

          Dialectic.Performance.Logger.log(
            "OpenAI chunk processing end (took #{processing_time_ms}ms)"
          )
        end)

        {:cont, context}

      {:error, reason} ->
        error_time = DateTime.utc_now()
        Dialectic.Performance.Logger.log("OpenAI chunk parsing error")
        Logger.error("Failed to parse OpenAI chunk: #{inspect(reason)}")
        {:cont, context}
    end
  end

  # Handle stream end message
  defp handle_stream_chunk(
         {:done, _data},
         context,
         _graph,
         _to_node,
         _live_view_topic,
         request_start_time
       ) do
    stream_end_time = DateTime.utc_now()
    total_stream_time_ms = DateTime.diff(stream_end_time, request_start_time, :millisecond)

    Dialectic.Performance.Logger.log(
      "OpenAI stream completed (total duration: #{total_stream_time_ms}ms)"
    )

    Logger.debug("Stream completed")
    {:cont, context}
  end

  # For backward compatibility with the base worker calls (no request_start_time)
  defp handle_stream_chunk({:data, data}, context, graph, to_node, live_view_topic) do
    handle_stream_chunk(
      {:data, data},
      context,
      graph,
      to_node,
      live_view_topic,
      DateTime.utc_now()
    )
  end

  defp handle_stream_chunk({:done, data}, context, graph, to_node, live_view_topic) do
    handle_stream_chunk(
      {:done, data},
      context,
      graph,
      to_node,
      live_view_topic,
      DateTime.utc_now()
    )
  end
end
