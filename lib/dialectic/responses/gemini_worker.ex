defmodule Dialectic.Workers.GeminiWorker do
  alias Dialectic.Responses.Utils

  @moduledoc """
  Worker for the Google Gemini AI model.
  """

  require Logger
  use Oban.Worker, queue: :api_request, max_attempts: 5
  @behaviour Dialectic.Workers.BaseAPIWorker

  # or a more specific version
  @model "gemini-2.0-flash"

  # Model-specific configuration:
  @impl true
  def api_key, do: System.get_env("GEMINI_API_KEY")

  @impl true
  def request_url do
    api_key = System.get_env("GEMINI_API_KEY")

    "https://generativelanguage.googleapis.com/v1beta/models/#{@model}:streamGenerateContent?key=#{api_key}"
  end

  @impl true
  def headers(_api_key) do
    [
      {"Content-Type", "application/json"}
    ]
  end

  @impl true
  def build_request_body(question) do
    %{
      contents: [
        %{
          parts: [
            %{
              text: question
            }
          ]
        }
      ],
      generationConfig: %{
        maxOutputTokens: 1024
      }
    }
  end

  @impl true
  def parse_chunk(chunk) do
    {:ok,
     [chunk |> String.replace_prefix(",", "") |> String.replace_prefix("[", "") |> Utils.decode()]}
  end

  @impl true
  def handle_result(
        %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [
                  %{
                    "text" => data
                  }
                ]
              }
            }
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
        %{"error" => %{"message" => message, "status" => status}} = error,
        _graph_id,
        to_node,
        live_view_topic
      ) do
    Logger.error("Gemini API error: #{inspect(error)}")

    # Format a user-friendly error message
    user_message = "Error from Gemini API: #{message} (#{status})"

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
    Logger.error("Unhandled Gemini response: #{inspect(other)}")
    :ok
  end

  @impl Oban.Worker
  defdelegate perform(job), to: Dialectic.Workers.BaseAPIWorker
end
