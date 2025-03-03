defmodule Dialectic.DbActions.DbWorker do
  use Oban.Worker, queue: :db_write, max_attempts: 5
  require Logger

  def perform(%Oban.Job{args: %{"id" => id}}) do
    Logger.info("Processing job with ID: #{id}")
    GraphManager.save_graph(id)
    :ok
  end

  def save_graph(path, wait \\ true) do
    create_job(path, wait)
  end

  defp create_job(path, true) do
    %{id: path}
    |> new(unique: [period: 30, keys: [:id]])
    |> Oban.insert()
  end

  defp create_job(path, false) do
    # Always save on completed request
    %{id: path}
    |> new()
    |> Oban.insert()
  end
end
