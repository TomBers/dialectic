defmodule Dialectic.Responses.LLMWorkerErrorTest do
  use Dialectic.DataCase, async: false

  alias Dialectic.Accounts.Graph
  alias Dialectic.DbActions.DbWorker
  alias Dialectic.Graph.Vertex
  alias Dialectic.GraphFixtures
  alias Dialectic.Workers.LLMWorker

  test "persists a terminal stream error without a LiveView subscriber" do
    previous_api_key = System.get_env("OPENAI_API_KEY")
    System.delete_env("OPENAI_API_KEY")

    on_exit(fn ->
      if previous_api_key do
        System.put_env("OPENAI_API_KEY", previous_api_key)
      else
        System.delete_env("OPENAI_API_KEY")
      end
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
                 "live_view_topic" => "no-subscriber-topic",
                 "provider" => "openai"
               }
             })

    assert GraphManager.find_node_by_id(graph.title, answer_node.id).content ==
             "OpenAI API key not configured"

    worker = Oban.Worker.to_string(DbWorker)
    snapshot_job = Repo.one!(from job in Oban.Job, where: job.worker == ^worker)
    assert :ok = DbWorker.perform(snapshot_job)

    persisted_graph = Repo.get!(Graph, graph.title)

    assert Enum.any?(persisted_graph.data["nodes"], fn node ->
             node["id"] == answer_node.id and node["content"] == "OpenAI API key not configured"
           end)
  end
end
