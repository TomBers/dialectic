defmodule Dialectic.DbActions.DbWorker do
  use Oban.Worker, queue: :db_write, max_attempts: 5
  require Logger

  def perform(%Oban.Job{args: %{"id" => id}}) do
    Logger.info("Processing job with ID: #{id}")
    GraphManager.save_graph(id)
    :ok
  end

  def save_graph(path) do
    %{id: path}
    |> new(unique: [period: 30, keys: [:id]])
    |> Oban.insert()
  end
end
