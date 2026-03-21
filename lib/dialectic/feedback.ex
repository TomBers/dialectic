defmodule Dialectic.Feedback do
  @moduledoc """
  Handles feedback form submissions from the about page.
  """

  require Logger

  @doc """
  Submits feedback. Accepts a map of feedback params.
  Returns `{:ok, :submitted}` on success or `{:error, reason}` on failure.
  """
  def submit(params) do
    Logger.info("Feedback received",
      feedback_type: Map.get(params, "feedback_type", "unknown")
    )

    {:ok, :submitted}
  end
end
