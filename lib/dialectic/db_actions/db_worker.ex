defmodule Dialectic.DbActions.DbWorker do
  use Oban.Worker, queue: :db_write, max_attempts: 5
  require Logger

  def perform(%Oban.Job{args: %{"id" => id}}) do
    Logger.info("Processing job with ID: #{id}")
    GraphManager.save_graph(id)
    :ok
  end

  def save_graph(path) do
    # TODO: Think about the timeout period.  Should it be 10 seconds?
    # I.e the save queue should unique for 10 secs needs to balance writes to vs performance
    %{id: path}
    |> new(unique: [period: 10, keys: [:id]])
    |> Oban.insert()
  end
end
