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
      {"x-api-key", "#{api_key}"},
      {"anthropic-version", "2023-06-01"},
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

  @impl true
  def build_request_body(question) do
    %{
      model: @model,
      max_tokens: 1024,
      messages: [
        %{
          role: "user",
          content: question
        }
      ]
    }
  end

  @impl true
  def extract_text(%{"content" => parts}) when is_list(parts) do
    text =
      parts
      |> Enum.flat_map(fn
        %{"type" => "text", "text" => t} when is_binary(t) -> [t]
        _ -> []
      end)
      |> Enum.join("")

    if text == "", do: nil, else: text
  end

  def extract_text(_), do: nil

  @impl Oban.Worker
  defdelegate perform(job), to: Dialectic.Workers.BaseAPIWorker
end
