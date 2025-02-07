defmodule Dialectic.Workers.DeepSeekWorker do
  alias Dialectic.Responses.Utils

  @moduledoc """
  Worker for the DeepSeek model.
  """
  require Logger
  use Oban.Worker, queue: :api_request, max_attempts: 5

  @behaviour Dialectic.Workers.BaseAPIWorker

  # Model-specific configuration:
  @impl true
  def api_key, do: System.get_env("DEEPSEEK_API_KEY")
  @impl true
  def request_url, do: "https://api.deepseek.com/chat/completions"

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
      model: "deepseek-chat",
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
  def parse_chunk(chunk), do: Utils.parse_chunk(chunk)

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
      when is_binary(data),
      do: Utils.process_chunk(graph_id, to_node, data, __MODULE__)

  @impl true
  def handle_result(other, _graph, _to_node) do
    IO.inspect(other, label: "Error")
    :ok
  end

  @impl Oban.Worker
  defdelegate perform(job), to: Dialectic.Workers.BaseAPIWorker
end
