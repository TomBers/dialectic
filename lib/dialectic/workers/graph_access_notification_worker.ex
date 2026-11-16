defmodule Dialectic.Workers.GraphAccessNotificationWorker do
  use Oban.Worker, queue: :db_write, max_attempts: 5

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"graph_title" => title}}) do
    Phoenix.PubSub.broadcast(
      Dialectic.PubSub,
      "graph_update:#{title}",
      {:graph_access_updated, title}
    )
  end
end
