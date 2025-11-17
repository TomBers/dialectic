defmodule Dialectic.Workers.OpenAIWorker do
  @moduledoc """
  DEPRECATED: Delegates to Dialectic.Workers.LLMWorker.

  This module remains to avoid routing/queue changes. All requests are forwarded
  to the provider-agnostic LLMWorker with provider set to "openai".
  """

  use Oban.Worker, queue: :openai_request, max_attempts: 5, priority: 0

  # -- Oban Perform Callback ----------------------------------------------------

  @impl Oban.Worker
  def perform(%Oban.Job{} = job) do
    args = Map.put(job.args || %{}, "provider", "openai")
    Dialectic.Workers.LLMWorker.perform(%Oban.Job{job | args: args})
  end
end
