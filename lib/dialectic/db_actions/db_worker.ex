defmodule Dialectic.DbActions.DbWorker do
  use Oban.Worker, queue: :db_write, max_attempts: 5
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

  def save_graph(path, wait \\ true) do
    # Build a portable JSON snapshot without exposing the raw digraph handle
    nodes =
      GraphManager.vertices(path)
      |> Enum.map(fn vid ->
        case GraphManager.vertex_label(path, vid) do
          %{} = v -> Dialectic.Graph.Vertex.serialize(v)
          _ -> nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    edges =
      GraphManager.vertices(path)
      |> Enum.flat_map(fn sid ->
        GraphManager.out_neighbours(path, sid)
        |> Enum.map(fn tid ->
          %{
            data: %{
              id: sid <> tid,
              source: sid,
              target: tid
            }
          }
        end)
      end)

    data = %{nodes: nodes, edges: edges}

    args = %{
      "id" => path,
      "data" => data,
      "ts" => DateTime.utc_now() |> DateTime.to_iso8601()
    }

    create_job(args, wait)
  end

  defp create_job(args, true) do
    args
    |> new(unique: [period: 30, keys: [:id]])
    |> Oban.insert()
  end

  defp create_job(args, false) do
    # Always save on completed request
    args
    |> new()
    |> Oban.insert()
  end
end
