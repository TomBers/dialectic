defmodule Dialectic.Integrations.VisibilityNotificationsTest do
  use Dialectic.DataCase, async: false
  import Dialectic.AccountsFixtures
  import Dialectic.McpFixtures
  alias Dialectic.Integrations.{ChatGrids, GridVisibility}
  alias Dialectic.Workers.GraphAccessNotificationWorker, as: Worker

  setup do
    user = user_fixture()
    {:ok, graph} = ChatGrids.create(user, grid_draft())
    Phoenix.PubSub.subscribe(Dialectic.PubSub, "graph_update:#{graph.title}")
    %{user: user, graph: graph}
  end

  test "MCP notification is persisted atomically and exact replay queues nothing", %{
    user: user,
    graph: graph
  } do
    params = %{
      "request_id" => Ecto.UUID.generate(),
      "visibility" => "public",
      "expected_revision" => graph.data_revision
    }

    assert {:ok, accepted} = GridVisibility.set(user, graph.slug, params)
    refute_received {:graph_access_updated, _}
    assert Repo.reload!(graph).is_public

    assert {:ok, ^accepted} = GridVisibility.set(user, graph.slug, params)
    jobs = notification_jobs()
    assert length(jobs) == 1
    refute Repo.in_transaction?()
    assert :ok = Worker.perform(hd(jobs))
    assert_received {:graph_access_updated, title}
    assert title == graph.title
  end

  test "rolling back the caller's transaction emits nothing and removes the notification", %{
    user: user,
    graph: graph
  } do
    assert {:error, :aborted} =
             Repo.transact(fn ->
               assert {:ok, _} = GridVisibility.change(graph, user, true)
               assert length(notification_jobs()) == 1
               refute_received {:graph_access_updated, _}
               Repo.rollback(:aborted)
             end)

    refute Repo.reload!(graph).is_public
    assert notification_jobs() == []
    refute_received {:graph_access_updated, _}
  end

  test "UI private transition queues access refresh after saving the new visibility", %{
    user: user,
    graph: graph
  } do
    assert {:ok, _} = GridVisibility.change(graph, user, true)
    for job <- notification_jobs(), do: Repo.delete!(job)

    assert {:ok, updated} = GridVisibility.change(graph, user, false)
    refute updated.is_public
    refute_received {:graph_access_updated, _}
    assert [job] = notification_jobs()
    assert :ok = Worker.perform(job)
    assert_received {:graph_access_updated, _}
    refute Repo.reload!(graph).is_public
  end

  defp notification_jobs do
    Repo.all(
      from j in Oban.Job,
        where: j.worker == "Dialectic.Workers.GraphAccessNotificationWorker"
    )
  end
end
