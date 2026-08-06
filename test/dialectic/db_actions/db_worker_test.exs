defmodule Dialectic.DbActions.DbWorkerTest do
  use Dialectic.DataCase, async: false

  alias Dialectic.DbActions.DbWorker

  test "queued snapshots replace their args with the latest snapshot" do
    graph_id = "latest-snapshot-#{System.unique_integer([:positive])}"

    assert {:ok, first_job} =
             DbWorker.save_snapshot(graph_id, %{"version" => 1}, "2026-08-06T10:00:00Z")

    assert {:ok, replaced_job} =
             DbWorker.save_snapshot(graph_id, %{"version" => 2}, "2026-08-06T10:00:01Z")

    assert replaced_job.id == first_job.id
    assert replaced_job.conflict?

    assert replaced_job.args == %{
             "id" => graph_id,
             "data" => %{"version" => 2},
             "ts" => "2026-08-06T10:00:01Z"
           }

    assert [persisted_job] = snapshot_jobs()
    assert persisted_job.id == first_job.id
    assert persisted_job.args == replaced_job.args
  end

  test "a snapshot arriving during execution is queued separately" do
    graph_id = "executing-snapshot-#{System.unique_integer([:positive])}"

    assert {:ok, first_job} =
             DbWorker.save_snapshot(graph_id, %{"version" => 1}, "2026-08-06T10:00:00Z")

    first_job
    |> Ecto.Changeset.change(state: "executing")
    |> Repo.update!()

    assert {:ok, pending_job} =
             DbWorker.save_snapshot(graph_id, %{"version" => 2}, "2026-08-06T10:00:01Z")

    refute pending_job.conflict?
    refute pending_job.id == first_job.id
    assert pending_job.args["data"] == %{"version" => 2}
    assert Enum.map(snapshot_jobs(), & &1.state) == ["executing", "available"]
  end

  defp snapshot_jobs do
    worker = Oban.Worker.to_string(DbWorker)
    Repo.all(from job in Oban.Job, where: job.worker == ^worker, order_by: job.id)
  end
end
