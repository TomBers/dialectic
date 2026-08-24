defmodule Dialectic.Responses.LLMWorkerErrorTest do
  use Dialectic.DataCase, async: false

  alias Dialectic.Accounts.Graph
  alias Dialectic.DbActions.DbWorker
  alias Dialectic.Graph.Vertex
  alias Dialectic.GraphFixtures
  alias Dialectic.Workers.LLMWorker

  test "defaults to Gemini and persists a terminal stream error without a LiveView subscriber" do
    previous_api_key = System.get_env("GOOGLE_API_KEY")
    previous_provider = System.get_env("LLM_PROVIDER")
    System.delete_env("GOOGLE_API_KEY")
    System.delete_env("LLM_PROVIDER")

    on_exit(fn ->
      restore_env("GOOGLE_API_KEY", previous_api_key)
      restore_env("LLM_PROVIDER", previous_provider)
    end)

    graph =
      GraphFixtures.insert_graph(%{
        title: "worker-error-#{System.unique_integer([:positive])}"
      })

    {_graph_struct, _digraph} = GraphManager.get_graph(graph.title)
    graph_manager = :global.whereis_name({:graph, graph.title})

    on_exit(fn ->
      if is_pid(graph_manager) and Process.alive?(graph_manager) do
        DynamicSupervisor.terminate_child(GraphSupervisor, graph_manager)
      end
    end)

    answer_node = GraphManager.add_node(graph.title, %Vertex{class: "answer", content: ""})

    assert {:discard, :missing_api_key} =
             LLMWorker.perform(%Oban.Job{
               id: 1,
               attempt: 1,
               max_attempts: 3,
               inserted_at: DateTime.utc_now(),
               scheduled_at: DateTime.utc_now(),
               args: %{
                 "question" => "Explain",
                 "to_node" => answer_node.id,
                 "graph" => graph.title,
                 "live_view_topic" => "no-subscriber-topic"
               }
             })

    assert GraphManager.find_node_by_id(graph.title, answer_node.id).content ==
             "Google API key not configured"

    worker = Oban.Worker.to_string(DbWorker)
    snapshot_job = Repo.one!(from job in Oban.Job, where: job.worker == ^worker)
    assert :ok = DbWorker.perform(snapshot_job)

    persisted_graph = Repo.get!(Graph, graph.title)

    assert Enum.any?(persisted_graph.data["nodes"], fn node ->
             node["id"] == answer_node.id and node["content"] == "Google API key not configured"
           end)
  end

  test "terminal guided failures release reservations and delete the failed branch" do
    previous_api_key = System.get_env("GOOGLE_API_KEY")
    previous_provider = System.get_env("LLM_PROVIDER")
    System.delete_env("GOOGLE_API_KEY")
    System.delete_env("LLM_PROVIDER")

    on_exit(fn ->
      restore_env("GOOGLE_API_KEY", previous_api_key)
      restore_env("LLM_PROVIDER", previous_provider)
    end)

    graph =
      GraphFixtures.insert_graph(%{
        title: "guided-worker-error-#{System.unique_integer([:positive])}"
      })

    {_graph_struct, _digraph} = GraphManager.get_graph(graph.title)
    graph_manager = :global.whereis_name({:graph, graph.title})

    on_exit(fn ->
      if is_pid(graph_manager) and Process.alive?(graph_manager) do
        DynamicSupervisor.terminate_child(GraphSupervisor, graph_manager)
      end
    end)

    plan_node =
      GraphManager.add_node(graph.title, %Vertex{
        class: "learning_plan",
        content: "Learning plan",
        guided_plan: %{version: 1}
      })

    question_node =
      GraphManager.add_child(
        graph.title,
        [plan_node],
        fn _ -> "Explore this path" end,
        "question",
        "tester"
      )

    answer_node =
      GraphManager.add_child(
        graph.title,
        [question_node],
        fn _ -> :ok end,
        "answer",
        "tester"
      )

    sibling_node =
      GraphManager.add_child(
        graph.title,
        [plan_node],
        fn _ -> :ok end,
        "thesis",
        "tester"
      )

    submission_key = "path:test-path"

    assert :ok =
             GraphManager.reserve_guided_submission(
               graph.title,
               plan_node.id,
               submission_key
             )

    assert {:discard, :missing_api_key} =
             LLMWorker.perform(%Oban.Job{
               id: 2,
               attempt: 1,
               max_attempts: 3,
               inserted_at: DateTime.utc_now(),
               scheduled_at: DateTime.utc_now(),
               args: %{
                 "question" => "Explain",
                 "to_node" => answer_node.id,
                 "graph" => graph.title,
                 "live_view_topic" => "guided-no-subscriber-topic",
                 "guided_submission" => %{
                   "plan_node_id" => plan_node.id,
                   "submission_key" => submission_key,
                   "cleanup_node_ids" => [question_node.id],
                   "cleanup_classes" => ["thesis"]
                 }
               }
             })

    refreshed_plan = GraphManager.find_node_by_id(graph.title, plan_node.id)
    refute submission_key in refreshed_plan.guided_submissions
    assert GraphManager.find_node_by_id(graph.title, question_node.id).deleted
    assert GraphManager.find_node_by_id(graph.title, answer_node.id).deleted
    assert GraphManager.find_node_by_id(graph.title, sibling_node.id).deleted
  end

  defp restore_env(name, nil), do: System.delete_env(name)
  defp restore_env(name, value), do: System.put_env(name, value)
end
