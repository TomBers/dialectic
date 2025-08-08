defmodule Dialectic.Workers.OpenAIWorker do
  alias Dialectic.Responses.Utils

  @moduledoc """
  Worker for the OpenAI Chat API.
  """
  require Logger
  use Oban.Worker, queue: :api_request, max_attempts: 5

  @behaviour Dialectic.Workers.BaseAPIWorker

  @model "gpt-5-mini-2025-08-07"
  # Model-specific configuration:

  @impl true
  def api_key, do: System.get_env("OPENAI_API_KEY")

  @impl true
  def request_url, do: "https://api.openai.com/v1/chat/completions"

  @impl true
  def headers(api_key) do
    [
      {"Authorization", "Bearer #{api_key}"},
      {"Content-Type", "application/json"}
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
  def handle_result(
        %{
          "error" => %{
            "code" => "unsupported_value",
            "message" => _message,
            "type" => "invalid_request_error"
          }
        } = error,
        _graph_id,
        to_node,
        live_view_topic
      ) do
    Logger.error("OpenAI organization verification error: #{inspect(error)}")

    # Format a user-friendly error message specific to organization verification
    user_message =
      "Your OpenAI organization requires verification to stream this model. Please visit https://platform.openai.com/settings/organization/general and click on 'Verify Organization'. If you just verified, it can take up to 15 minutes for access to propagate."

    # Broadcast the error to the LiveView
    Phoenix.PubSub.broadcast(
      Dialectic.PubSub,
      live_view_topic,
      {:stream_error, user_message, :node_id, to_node}
    )

    :ok
  end

  @impl true
  def handle_result(
        %{"error" => %{"message" => message, "type" => "invalid_request_error"}} = error,
        _graph_id,
        to_node,
        live_view_topic
      ) do
    Logger.error("OpenAI API error: #{inspect(error)}")

    # Format a user-friendly error message
    user_message = "Error from OpenAI API: #{message}"

    # Broadcast the error to the LiveView
    Phoenix.PubSub.broadcast(
      Dialectic.PubSub,
      live_view_topic,
      {:stream_error, user_message, :node_id, to_node}
    )

    :ok
  end

  @impl true
  def handle_result(other, _graph, _to_node, _live_view_topic) do
    Logger.error("Unhandled OpenAI response: #{inspect(other)}")
    :ok
  end

  @impl Oban.Worker
  defdelegate perform(job), to: Dialectic.Workers.BaseAPIWorker
end
