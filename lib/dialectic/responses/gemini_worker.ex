defmodule Dialectic.Workers.GeminiWorker do
  alias Dialectic.Responses.Utils

  @moduledoc """
  Worker for the Google Gemini AI model.
  """

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

    "https://generativelanguage.googleapis.com/v1beta/models/#{@model}:generateContent?key=#{api_key}"
  end

  @impl true
  def headers(_api_key) do
    [
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
  def extract_text(%{"candidates" => candidates}) when is_list(candidates) do
    text =
      candidates
      |> Enum.flat_map(fn
        %{"content" => %{"parts" => parts}} when is_list(parts) ->
          Enum.flat_map(parts, fn
            %{"text" => t} when is_binary(t) -> [t]
            _ -> []
          end)

        _ ->
          []
      end)
      |> Enum.join("")

    if text == "", do: nil, else: text
  end

  def extract_text(_), do: nil

  @impl Oban.Worker
  defdelegate perform(job), to: Dialectic.Workers.BaseAPIWorker
end
