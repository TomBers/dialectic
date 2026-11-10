defmodule Dialectic.Workers.ExplorationWorker do
  use Oban.Worker,
    queue: :api_request,
    max_attempts: 5,
    unique: [period: :infinity, keys: [:user_id, :request_id]]

  alias Dialectic.Integrations.Explorations

  @impl true
  def perform(%Oban.Job{
        args: %{"user_id" => user_id, "request_id" => request_id},
        attempt: attempt,
        max_attempts: maximum
      }) do
    Explorations.advance(user_id, request_id)
  rescue
    error ->
      if attempt >= maximum, do: Explorations.fail(user_id, request_id, "generation_stopped")
      reraise error, __STACKTRACE__
  end
end
