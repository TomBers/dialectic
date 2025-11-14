defmodule Dialectic.DbActions.DbWorker do
  use Oban.Worker, queue: :db_write, max_attempts: 5
  require Logger

  def perform(%Oban.Job{args: %{"id" => id, "data" => data} = args}) do
    final? = Map.get(args, "final") in [true, "true", 1, "1"]

    if final? do
      Logger.info("Persisting FINAL snapshot for #{id}")
      Dialectic.DbActions.Graphs.save_graph(id, data)
      :ok
    else
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
  end

  # Backwards compatibility: handle legacy jobs without embedded snapshot
  def perform(%Oban.Job{args: %{"id" => id}}) do
    Logger.info("Legacy job detected, falling back to in-memory save for #{id}")
    GraphManager.save_graph(id)
    :ok
  end

  def save_graph(path, wait \\ true, opts \\ []) do
    # Build a portable JSON snapshot without exposing the raw digraph handle
    {nodes, edges} =
      GraphManager.vertices(path)
      |> Enum.reduce({[], []}, fn vid, {nodes_acc, edges_acc} ->
        node =
          case GraphManager.vertex_label(path, vid) do
            %{} = v -> Dialectic.Graph.Vertex.serialize(v)
            _ -> nil
          end

        node_acc =
          if is_nil(node) do
            nodes_acc
          else
            [node | nodes_acc]
          end

        out_edges =
          GraphManager.out_neighbours(path, vid)
          |> Enum.map(fn tid ->
            %{
              data: %{
                id: vid <> tid,
                source: vid,
                target: tid
              }
            }
          end)

        {node_acc, out_edges ++ edges_acc}
      end)

    nodes = Enum.reverse(nodes)
    edges = Enum.reverse(edges)

    data = %{nodes: nodes, edges: edges}

    final? = Keyword.get(opts, :final, false)

    ts =
      if final? do
        nil
      else
        DateTime.utc_now() |> DateTime.to_iso8601()
      end

    base = %{
      "id" => path,
      "data" => data
    }

    args =
      base
      |> Map.merge(if ts, do: %{"ts" => ts}, else: %{})
      |> Map.merge(if final?, do: %{"final" => true}, else: %{})

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
