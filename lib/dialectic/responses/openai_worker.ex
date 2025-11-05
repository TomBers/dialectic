defmodule Dialectic.Workers.OpenAIWorker do
  @moduledoc """
  Worker for the OpenAI Chat API.
  """
  require Logger
  use Oban.Worker, queue: :openai_request, max_attempts: 5, priority: 0

  @behaviour Dialectic.Workers.BaseAPIWorker

  @model "gpt-5-nano-2025-08-07"
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
      {"Accept", "application/json"}
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
      reasoning_effort: "minimal",
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
