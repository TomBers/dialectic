defmodule Dialectic.Feedback do
  @moduledoc """
  Submits user feedback to a Google Form via HTTP POST using Req.

  Configuration is read from `config :dialectic, :feedback` which must contain:

    - `:form_id` — the Google Form's public ID
    - `:fields` — a map of atom keys to Google Form `entry.XXXX` field names

  Example config:

      config :dialectic, :feedback,
        form_id: "1FAIpQLSc...",
        fields: %{
          feedback_type: "entry.1591633300",
          feedback: "entry.326955045",
          suggestions: "entry.1696159737",
          name: "entry.485428648",
          email: "entry.879531967"
        }
  """

  require Logger

  @doc """
  Submits feedback to the configured Google Form.

  Accepts a map with any of the following keys (all optional except `:feedback`):

    * `:feedback_type` — one of "Comments", "Questions", "Bug Reports", "Feature Request"
    * `:feedback` — the main feedback text (required)
    * `:suggestions` — suggestions for improvement
    * `:name` — submitter's name
    * `:email` — submitter's email

  Returns `{:ok, :submitted}` on success or `{:error, reason}` on failure.
  """
  @spec submit(map()) :: {:ok, :submitted} | {:error, term()}
  def submit(params) when is_map(params) do
    config = Application.get_env(:dialectic, :feedback, [])
    form_id = Keyword.fetch!(config, :form_id)
    fields = Keyword.fetch!(config, :fields)

    form_data =
      fields
      |> Enum.reduce(%{}, fn {key, entry_id}, acc ->
        case Map.get(params, key) || Map.get(params, to_string(key)) do
          nil -> acc
          "" -> acc
          value -> Map.put(acc, entry_id, value)
        end
      end)

    url = "https://docs.google.com/forms/d/e/#{form_id}/formResponse"

    case Req.post(url, form: form_data, redirect: false, retry: false, receive_timeout: 10_000) do
      {:ok, %Req.Response{status: status}} when status in 200..399 ->
        Logger.info("Feedback submitted successfully to Google Form")
        {:ok, :submitted}

      {:ok, %Req.Response{status: status}} ->
        Logger.warning("Google Form returned unexpected status #{status}")
        {:error, :unexpected_status}

      {:error, reason} ->
        Logger.error("Failed to submit feedback to Google Form: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
