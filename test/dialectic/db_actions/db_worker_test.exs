defmodule Dialectic.DbActions.DbWorkerTest do
  use Dialectic.DataCase, async: false

  alias Dialectic.DbActions.DbWorker
  alias Dialectic.GraphFixtures

  test "queued snapshots replace their args with the latest snapshot" do
    graph_id = "latest-snapshot-#{System.unique_integer([:positive])}"

    assert {:ok, first_job} = DbWorker.save_snapshot(graph_id, %{"version" => 1}, 1)

    assert {:ok, replaced_job} = DbWorker.save_snapshot(graph_id, %{"version" => 2}, 2)

    assert replaced_job.id == first_job.id
    assert replaced_job.conflict?

    assert replaced_job.args == %{
             "id" => graph_id,
             "data" => %{"version" => 2},
             "revision" => 2
           }

    assert [persisted_job] = snapshot_jobs()
    assert persisted_job.id == first_job.id
    assert persisted_job.args == replaced_job.args
  end

  test "a snapshot arriving during execution is queued separately" do
    graph_id = "executing-snapshot-#{System.unique_integer([:positive])}"

    assert {:ok, first_job} = DbWorker.save_snapshot(graph_id, %{"version" => 1}, 1)

    first_job
    |> Ecto.Changeset.change(state: "executing")
    |> Repo.update!()

    assert {:ok, pending_job} = DbWorker.save_snapshot(graph_id, %{"version" => 2}, 2)

    refute pending_job.conflict?
    refute pending_job.id == first_job.id
    assert pending_job.args["data"] == %{"version" => 2}
    assert Enum.map(snapshot_jobs(), & &1.state) == ["executing", "available"]
  end

  test "persists only snapshots with newer revisions" do
    graph =
      GraphFixtures.insert_graph(%{
        title: "persisted-revision-#{System.unique_integer([:positive])}",
        data: %{"version" => 0}
      })

    assert :ok =
             DbWorker.perform(%Oban.Job{
               args: %{"id" => graph.title, "data" => %{"version" => 2}, "revision" => 2}
             })

    assert %{data: %{"version" => 2}, data_revision: 2} = Repo.get!(graph.__struct__, graph.title)

    assert :ok =
             DbWorker.perform(%Oban.Job{
               args: %{"id" => graph.title, "data" => %{"version" => 1}, "revision" => 1}
             })

    assert %{data: %{"version" => 2}, data_revision: 2} = Repo.get!(graph.__struct__, graph.title)
  end

  test "converts legacy timestamped jobs into ordered revisions" do
    graph =
      GraphFixtures.insert_graph(%{
        title: "legacy-timestamp-#{System.unique_integer([:positive])}",
        data: %{"version" => 1}
      })

    timestamp = "2026-08-06T10:00:00.123456Z"
    {:ok, parsed_timestamp, _offset} = DateTime.from_iso8601(timestamp)

    assert :ok =
             DbWorker.perform(%Oban.Job{
               args: %{
                 "id" => graph.title,
                 "data" => %{"version" => 2},
                 "ts" => timestamp
               }
             })

    assert %{data: %{"version" => 2}, data_revision: revision} =
             Repo.get!(graph.__struct__, graph.title)

    assert revision == DateTime.to_unix(parsed_timestamp, :microsecond)
  end

  test "discards malformed timestamps instead of overwriting graph data" do
    graph =
      GraphFixtures.insert_graph(%{
        title: "invalid-timestamp-#{System.unique_integer([:positive])}",
        data: %{"version" => 1}
      })

    assert {:discard, :invalid_snapshot_timestamp} =
             DbWorker.perform(%Oban.Job{
               args: %{
                 "id" => graph.title,
                 "data" => %{"version" => 2},
                 "ts" => "not-a-timestamp"
               }
             })

    assert %{data: %{"version" => 1}, data_revision: 0} = Repo.get!(graph.__struct__, graph.title)
  end

  defp snapshot_jobs do
    worker = Oban.Worker.to_string(DbWorker)
    Repo.all(from job in Oban.Job, where: job.worker == ^worker, order_by: job.id)
  end
end
