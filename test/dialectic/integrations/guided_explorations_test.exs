defmodule Dialectic.Integrations.GuidedExplorationsTest do
  use Dialectic.DataCase, async: false

  import Dialectic.AccountsFixtures
  alias Dialectic.Integrations.{ChatGrids, Exploration, Explorations, GridAction, GridActions}
  alias Dialectic.Accounts.Graph

  setup do
    user = user_fixture()

    params = %{
      "request_id" => Ecto.UUID.generate(),
      "question" => "What makes evidence persuasive?"
    }

    {:ok, result} = ChatGrids.start_guided_exploration(user, params)

    on_exit(fn ->
      case :global.whereis_name({:graph, result.graph.title}) do
        pid when is_pid(pid) -> DynamicSupervisor.terminate_child(GraphSupervisor, pid)
        _ -> :ok
      end
    end)

    %{user: user, params: params, result: result}
  end

  test "one question produces a bounded, durable exploration with synthesis of both branches", %{
    user: user,
    params: params,
    result: result
  } do
    assert result.exploration.stage == "opening"
    assert result.status == "queued"
    assert {:snooze, 3} = Explorations.advance(user.id, params["request_id"])
    assert Repo.aggregate(GridAction, :count) == 1

    for {stage, expected_count} <- [{"opening", 2}, {"testing", 3}, {"deepening", 4}] do
      complete_current(
        user,
        params,
        result.graph.title,
        "Completed #{stage} with specific findings"
      )

      assert {:snooze, 3} = Explorations.advance(user.id, params["request_id"])
      assert Repo.aggregate(GridAction, :count) == expected_count
      assert {:snooze, 3} = Explorations.advance(user.id, params["request_id"])
      assert Repo.aggregate(GridAction, :count) == expected_count
      assert {:ok, replay} = ChatGrids.start_guided_exploration(user, params)
      assert replay.status == "generating"
    end

    exploration = Repo.one!(Exploration)
    synthesis = Repo.get_by!(GridAction, user_id: user.id, action: "exploration_synthesizing")
    job = Repo.get!(Oban.Job, synthesis.job_id)
    assert job.args["instruction"] =~ "Completed testing with specific findings"
    assert job.args["instruction"] =~ "Completed deepening with specific findings"
    assert job.args["instruction"] =~ "not verified evidence"
    {_, graph} = GraphManager.get_graph(result.graph.title)

    assert MapSet.new(:digraph.in_neighbours(graph, synthesis.node_id)) ==
             MapSet.new([
               exploration.steps["testing"]["node_id"],
               exploration.steps["deepening"]["node_id"]
             ])

    complete_current(user, params, result.graph.title, "A qualified synthesis")
    assert :ok = Explorations.advance(user.id, params["request_id"])
    assert :ok = Explorations.advance(user.id, params["request_id"])
    assert {:ok, final} = GridActions.get_operation(user, params["request_id"])
    assert final.status == "completed"
    assert final.exploration.completed_steps == 4
    assert length(final.nodes) == 5
    assert List.last(final.nodes).content == "A qualified synthesis"
    assert Repo.aggregate(GridAction, :count) == 4
    assert {:error, :request_conflict} = ChatGrids.start_exploration(user, params)
    assert {:error, :not_found} = GridActions.get_operation(user_fixture(), params["request_id"])
  end

  test "failed generation and a locked grid stop the workflow without recreating anything", %{
    user: user,
    params: params,
    result: result
  } do
    operation = Repo.one!(GridAction)

    Repo.get!(Oban.Job, operation.job_id)
    |> Ecto.Changeset.change(state: "discarded")
    |> Repo.update!()

    assert :ok = Explorations.advance(user.id, params["request_id"])
    assert {:ok, failed} = GridActions.get_operation(user, params["request_id"])
    assert failed.status == "failed"
    assert failed.exploration.error == "generation_failed"
    assert Repo.aggregate(GridAction, :count) == 1

    Repo.one!(Exploration) |> Ecto.Changeset.change(stage: "opening") |> Repo.update!()

    Repo.get!(Graph, result.graph.title)
    |> Ecto.Changeset.change(is_locked: true)
    |> Repo.update!()

    assert :ok = Explorations.advance(user.id, params["request_id"])
    assert Repo.one!(Exploration).error == "editing_stopped"
    assert Repo.aggregate(GridAction, :count) == 1
  end

  test "a crash after a branch commit reuses the same operation on retry", %{
    user: user,
    params: params,
    result: result
  } do
    complete_current(user, params, result.graph.title, "An opening answer")
    Explorations.advance(user.id, params["request_id"])
    exploration = Repo.one!(Exploration)
    exploration |> Ecto.Changeset.change(stage: "opening", steps: %{}) |> Repo.update!()
    assert {:snooze, 3} = Explorations.advance(user.id, params["request_id"])
    assert Repo.aggregate(GridAction, :count) == 2
    assert Repo.one!(Exploration).steps == exploration.steps
  end

  test "cancelled coordination is reported as failed, including after job pruning", %{
    user: user,
    params: params
  } do
    job = Repo.get!(Oban.Job, Repo.one!(Exploration).coordinator_job_id)
    job = job |> Ecto.Changeset.change(state: "cancelled") |> Repo.update!()

    assert {:ok, %{status: "failed", exploration: %{error: "coordination_stopped"}}} =
             GridActions.get_operation(user, params["request_id"])

    Repo.delete!(job)
    assert {:ok, %{status: "failed"}} = GridActions.get_operation(user, params["request_id"])
    assert Repo.aggregate(GridAction, :count) == 1
  end

  test "a saved branch survives graph restart and completed job pruning", %{
    user: user,
    params: params,
    result: result
  } do
    complete_current(user, params, result.graph.title, "A durable opening")
    operation = Repo.one!(GridAction)
    Repo.get!(Oban.Job, operation.job_id) |> Repo.delete!()
    pid = :global.whereis_name({:graph, result.graph.title})
    DynamicSupervisor.terminate_child(GraphSupervisor, pid)
    assert {:snooze, 3} = Explorations.advance(user.id, params["request_id"])

    assert {:ok, %{status: "generating", nodes: nodes}} =
             GridActions.get_operation(user, params["request_id"])

    assert Enum.at(nodes, 1).content == "A durable opening"
    assert Repo.aggregate(GridAction, :count) == 2
  end

  defp complete_current(user, params, title, content) do
    exploration = Repo.one!(Exploration)

    operation =
      if exploration.stage == "opening",
        do: Repo.get_by!(GridAction, request_id: params["request_id"], user_id: user.id),
        else:
          Repo.get_by!(GridAction, action: "exploration_" <> exploration.stage, user_id: user.id)

    GraphManager.set_node_content(title, operation.answer_node_id || operation.node_id, content)
    {_, graph} = GraphManager.get_graph(title)

    Repo.get!(Graph, title)
    |> Ecto.Changeset.change(data: Dialectic.Graph.Serialise.graph_to_json(graph))
    |> Repo.update!()

    Repo.get!(Oban.Job, operation.job_id)
    |> Ecto.Changeset.change(state: "completed")
    |> Repo.update!()
  end
end
