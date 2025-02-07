defmodule Dialectic.Workers.OpenAIWorker do
  @moduledoc """
  Worker for the OpenAI Chat API.
  """
  require Logger
  use Oban.Worker, queue: :api_request, max_attempts: 5

  @behaviour Dialectic.Workers.BaseAPIWorker

  @model "gpt-3.5-turbo"
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
            "You are an expert philosopher, helping the user better understand key philosophical points. Please keep your answers concise and to the point."
        },
        %{role: "user", content: question}
      ]
    }
  end

  @impl true
  def handle_result(
        %{
          "choices" => [
            %{"delta" => %{"content" => data}}
          ]
        },
        graph_id,
        to_node
      )
      when is_binary(data) do
    Logger.info(data, label: "OpenAI Response")

    Phoenix.PubSub.broadcast(
      Dialectic.PubSub,
      graph_id,
      {:stream_chunk, data, :node_id, to_node}
    )
  end

  @impl true
  def handle_result(other, _graph, _to_node) do
    IO.inspect(other, label: "Error")
    :ok
  end

  @impl Oban.Worker
  defdelegate perform(job), to: Dialectic.Workers.BaseAPIWorker
end
