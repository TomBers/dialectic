defmodule Dialectic.Workers.DeepSeekWorker do
  @moduledoc """
  Worker for the DeepSeek model.
  """
  use Oban.Worker, queue: :api_request, max_attempts: 5

  @behaviour Dialectic.Workers.BaseAPIWorker

  # Model-specific configuration:
  @impl true
  def api_key, do: System.get_env("DEEPSEEK_API_KEY")
  @impl true
  def base_url, do: "https://api.deepseek.com"
  @impl true
  def request_path, do: "chat/completions"

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
    Phoenix.PubSub.broadcast(
      Dialectic.PubSub,
      graph_id,
      {:stream_chunk, data, :node_id, to_node}
    )
  end

  @impl true
  def handle_result(_other, _graph, _to_node), do: :ok

  @impl Oban.Worker
  defdelegate perform(job), to: Dialectic.Workers.BaseAPIWorker
end
