defmodule Dialectic.DbActions.DbWorker do
  @moduledoc """
  Oban worker for persisting graph snapshots to the database.

  Uses Oban uniqueness to debounce rapid save requests. If multiple saves
  for the same graph are queued within a short window, they will be
  coalesced into a single queued job. With the current uniqueness
  configuration, the first queued job is kept and later duplicate inserts are
  rejected, which prevents unnecessary database writes when multiple
  operations trigger saves in quick succession (e.g., ask_and_answer
  creating question + answer nodes).
  """

  use Oban.Worker,
    queue: :db_write,
    max_attempts: 5,
    # Debounce: only one job per graph_id within 2 seconds
    # Include executing and retryable states to ensure ongoing jobs also
    # prevent duplicate inserts, maximizing the debounce effect.
    unique: [
      period: 2,
      keys: [:id],
      states: [:available, :scheduled, :executing, :retryable]
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
  will be coalesced into a single database write. Note that the first job's
  data will be used (uniqueness prevents insertion of duplicates), so callers
  should ensure the most important save happens first, or accept that rapid
  saves will use slightly stale data (which is fine since the timestamp check
  in save_graph_if_newer provides additional protection).
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
