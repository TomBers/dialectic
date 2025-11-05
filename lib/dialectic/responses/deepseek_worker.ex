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
  def request_options do
    [
      connect_options: [timeout: 30_000],
      receive_timeout: 30_000,
      retry: :transient,
      max_retries: 2
    ]
  end

  # model - deepseek-chat points to Deepseek-V3 https://api-docs.deepseek.com/
  @impl true
  def build_request_body(question) do
    %{
      model: "deepseek-chat",
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
  def extract_text(%{"choices" => choices}) when is_list(choices) do
    text =
      choices
      |> Enum.flat_map(fn
        %{"message" => %{"content" => t}} when is_binary(t) -> [t]
        _ -> []
      end)
      |> Enum.join("")

    if text == "", do: nil, else: text
  end

  def extract_text(_), do: nil

  @impl Oban.Worker
  defdelegate perform(job), to: Dialectic.Workers.BaseAPIWorker
end
