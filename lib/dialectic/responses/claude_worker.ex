defmodule Dialectic.Workers.ClaudeWorker do
  alias Dialectic.Responses.Utils

  @moduledoc """
  Worker for the Claude AI model.
  """
  require Logger
  use Oban.Worker, queue: :api_request, max_attempts: 5
  @behaviour Dialectic.Workers.BaseAPIWorker

  @model "claude-3-sonnet-20240229"

  # Model-specific configuration:
  @impl true
  def api_key, do: System.get_env("ANTHROPIC_API_KEY")

  @impl true
  def request_url, do: "https://api.anthropic.com/v1/messages"

  @impl true
  def headers(api_key) do
    [
      {"x-api-key", api_key},
      {"content-type", "application/json"},
      {"anthropic-version", "2023-06-01"}
    ]
  end

  @impl true
  def build_request_body(question) do
    %{
      model: @model,
      max_tokens: 1024,
      stream: true,
      messages: [
        %{
          role: "user",
          content: question
        }
      ]
    }
  end

  @impl true
  def parse_chunk(chunk), do: Utils.parse_chunk(chunk)

  @impl true
  def handle_result(
        %{
          "delta" => %{
            "text" => data
          }
        },
        graph_id,
        to_node
      )
      when is_binary(data),
      do: Utils.process_chunk(graph_id, to_node, data, __MODULE__)

  @impl true
  def handle_result(other, _graph, _to_node) do
    IO.inspect(other, label: "handle_result Error")
    :ok
  end

  @impl Oban.Worker
  defdelegate perform(job), to: Dialectic.Workers.BaseAPIWorker
end
