defmodule Dialectic.Feedback do
  @moduledoc """
  Handles feedback form submissions from the about page.
  Submits feedback to a Google Form which populates a linked Google Sheet.
  """

  require Logger

  @google_form_id "1yHdX6klDKynaVl-hHnjbB-B1BldASFS_f7Pnb0lw3SQ"
  @form_url "https://docs.google.com/forms/d/#{@google_form_id}/formResponse"

  # Mapping of our form param keys to Google Form entry IDs
  @entry_ids %{
    "feedback_type" => "entry.1591633300",
    "feedback" => "entry.326955045",
    "suggestions" => "entry.1696159737",
    "name" => "entry.485428648",
    "email" => "entry.879531967"
  }

  @doc """
  Submits feedback. Accepts a map of feedback params.
  Returns `{:ok, :submitted}` on success or `{:error, reason}` on failure.
  """
  def submit(params) do
    Logger.info("Submitting feedback to Google Form",
      feedback_type: Map.get(params, "feedback_type", "unknown")
    )

    form_data = build_form_data(params)

    case Req.post(@form_url, form: form_data, redirect: false) do
      {:ok, %Req.Response{status: status}} when status in 200..399 ->
        Logger.info("Feedback submitted successfully", status: status)
        {:ok, :submitted}

      {:ok, %Req.Response{status: status, body: body}} ->
        Logger.error("Google Form submission failed",
          status: status,
          body: String.slice(to_string(body), 0, 500)
        )

        {:error, "Google Form returned status #{status}"}

      {:error, reason} ->
        Logger.error("Google Form submission request failed", error: inspect(reason))
        {:error, reason}
    end
  end

  defp build_form_data(params) do
    Enum.reduce(@entry_ids, [], fn {param_key, entry_id}, acc ->
      value = Map.get(params, param_key, "")
      [{entry_id, value} | acc]
    end)
  end
end
