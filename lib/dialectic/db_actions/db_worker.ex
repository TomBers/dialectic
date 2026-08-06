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

  def perform(%Oban.Job{args: %{"id" => id, "data" => data, "revision" => revision}})
      when is_integer(revision) do
    persist_if_newer(id, data, revision)
  end

  # Backwards compatibility for timestamped jobs queued before data revisions.
  def perform(%Oban.Job{args: %{"id" => id, "data" => data, "ts" => ts}})
      when is_binary(ts) do
    persist_if_newer(id, data, ts)
  end

  def perform(%Oban.Job{args: %{"id" => id, "data" => data}}) do
    Logger.info("Persisting legacy graph snapshot for #{id} without a revision")

    case Dialectic.DbActions.Graphs.save_graph_if_newer(id, data, 1) do
      {:ok, :updated} -> :ok
      {:error, :stale} -> :ok
      {:error, reason} -> {:error, reason}
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
  def save_snapshot(path, data, revision) when is_integer(revision) do
    args = %{
      "id" => path,
      "data" => data,
      "revision" => revision
    }

    create_job(args)
  end

  defp create_job(args) do
    args
    |> new()
    |> Oban.insert()
  end

  defp persist_if_newer(id, data, revision) do
    Logger.info("Persisting graph snapshot for #{id} (revision=#{revision})")

    case Dialectic.DbActions.Graphs.save_graph_if_newer(id, data, revision) do
      {:ok, :updated} ->
        :ok

      {:error, :stale} ->
        Logger.info("Skipped stale snapshot for #{id} (revision=#{revision})")
        :ok

      {:error, :invalid_timestamp} ->
        {:discard, :invalid_snapshot_timestamp}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
