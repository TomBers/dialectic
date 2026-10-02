defmodule Dialectic.DbActions.GraphSnapshotTest do
  use Dialectic.DataCase, async: false

  alias Dialectic.Accounts.Graph
  alias Dialectic.DbActions.{DbWorker, Graphs}
  alias Dialectic.Graph.Serialise
  alias Dialectic.GraphFixtures

  @original_updated_at ~U[2026-01-01 12:00:00Z]

  setup do
    graph =
      GraphFixtures.insert_graph(%{
        title: "snapshot-date-#{System.unique_integer([:positive])}",
        data: %{
          "nodes" => [
            %{"id" => "3", "content" => "Third", "class" => "answer"},
            %{"id" => "2", "content" => "Second", "class" => "answer"},
            %{"id" => "1", "content" => "First", "class" => "origin"}
          ],
          "edges" => [
            %{"data" => %{"id" => "2_3", "source" => "2", "target" => "3"}},
            %{"data" => %{"id" => "1_2", "source" => "1", "target" => "2"}}
          ]
        }
      })
      |> Ecto.Changeset.change(updated_at: @original_updated_at)
      |> Repo.update!()

    %{graph: graph}
  end

  test "shutdown after reading preserves the date despite serialization differences", %{
    graph: graph
  } do
    shutdown(graph)

    stored = Repo.get!(Graph, graph.title)
    assert stored.updated_at == @original_updated_at
    assert stored.data_revision > graph.data_revision
    assert Serialise.equivalent?(stored.data, graph.data)
  end

  test "shutdown persists unsaved edits and updates the date", %{graph: graph} do
    shutdown(graph, fn digraph ->
      {vertex_id, vertex} = :digraph.vertex(digraph, "2")
      :digraph.add_vertex(digraph, vertex_id, %{vertex | content: "Edited answer"})
    end)

    stored = Repo.get!(Graph, graph.title)
    assert DateTime.compare(stored.updated_at, @original_updated_at) == :gt
    assert Enum.any?(stored.data["nodes"], &(&1["content"] == "Edited answer"))
  end

  test "equivalent queued snapshots advance revisions without changing dates", %{graph: graph} do
    snapshot = %{
      graph.data
      | "nodes" => Enum.reverse(graph.data["nodes"]),
        "edges" => Enum.reverse(graph.data["edges"])
    }

    assert :ok =
             DbWorker.perform(%Oban.Job{
               args: %{"id" => graph.title, "data" => snapshot, "revision" => 2}
             })

    stored = Repo.get!(Graph, graph.title)
    assert stored.updated_at == @original_updated_at
    assert stored.data_revision == 2

    stale_snapshot = put_in(snapshot, ["nodes", Access.at(0), "content"], "Stale answer")
    assert {:error, :stale} = Graphs.save_graph_if_newer(graph.title, stale_snapshot, 1)
    assert Repo.get!(Graph, graph.title) == stored
  end

  test "edge changes update the date", %{graph: graph} do
    snapshot = %{graph.data | "edges" => []}

    assert {:ok, :updated} = Graphs.save_graph_if_newer(graph.title, snapshot, 1)

    stored = Repo.get!(Graph, graph.title)
    assert stored.data["edges"] == []
    assert DateTime.compare(stored.updated_at, @original_updated_at) == :gt
  end

  test "shutdown after an already persisted edit preserves its date", %{graph: graph} do
    snapshot = put_in(graph.data, ["nodes", Access.at(0), "content"], "Saved answer")
    assert {:ok, :updated} = Graphs.save_graph_if_newer(graph.title, snapshot, 1)

    saved_graph =
      Repo.get!(Graph, graph.title)
      |> Ecto.Changeset.change(updated_at: @original_updated_at)
      |> Repo.update!()

    shutdown(saved_graph)

    stored = Repo.get!(Graph, graph.title)
    assert stored.updated_at == saved_graph.updated_at
    assert Serialise.equivalent?(stored.data, snapshot)
  end

  defp shutdown(graph, edit \\ fn _digraph -> :ok end) do
    digraph = Serialise.json_to_graph(graph.data)
    previous = Application.fetch_env!(:dialectic, :sync_tasks_for_testing)

    try do
      edit.(digraph)
      Application.put_env(:dialectic, :sync_tasks_for_testing, false)
      assert :ok = GraphManager.terminate(:shutdown, {graph, digraph})
    after
      Application.put_env(:dialectic, :sync_tasks_for_testing, previous)
      :digraph.delete(digraph)
    end
  end
end
