defmodule Dialectic.DbActions.DbWorker do
  @moduledoc """
  Oban worker for persisting graph snapshots to the database.

  Uses Oban uniqueness to debounce rapid save requests.
  """

  use Oban.Worker,
    queue: :db_write,
    max_attempts: 5,
    replace: [
      available: [:args],
      scheduled: [:args],
      retryable: [:args]
    ],
    unique: [
      period: 2,
      keys: [:id],
      states: [:available, :scheduled, :retryable]
    ]

  require Logger

  def perform(%Oban.Job{args: %{"id" => id, "data" => data} = args}) do
    ts = Map.get(args, "ts")

    case ts do
      ts when is_binary(ts) ->
        Logger.info("Persisting graph snapshot for #{id} (ts=#{ts})")

        case Dialectic.DbActions.Graphs.save_graph_if_newer(id, data, ts) do
          {:ok, :updated} ->
            :ok

          {:error, :stale} ->
            Logger.info("Skipped stale snapshot for #{id} (ts=#{ts})")
            :ok

          _ ->
            Logger.info("Falling back to unconditional save for #{id}")
            Dialectic.DbActions.Graphs.save_graph(id, data)
            :ok
        end

      _ ->
        Logger.info("Persisting graph snapshot for #{id} (no ts)")
        Dialectic.DbActions.Graphs.save_graph(id, data)
        :ok
    end
  end

  # Backwards compatibility: handle legacy jobs without embedded snapshot
  def perform(%Oban.Job{args: %{"id" => id}}) do
    Logger.info("Legacy job detected, falling back to in-memory save for #{id}")
    GraphManager.save_graph(id)
    :ok
  end

  @doc """
  Queue a graph snapshot for persistence.

  Multiple calls for the same graph within the debounce window (2 seconds)
  will be coalesced into a single database write.
  """
  def save_snapshot(path, data, ts) do
    args = %{
      "id" => path,
      "data" => data,
      "ts" => ts
    }

    create_job(args)
  end

  defp create_job(args) do
    args
    |> new()
    |> Oban.insert()
  end
end
