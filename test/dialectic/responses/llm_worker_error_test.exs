defmodule Dialectic.Responses.LLMWorkerErrorTest do
  use Dialectic.DataCase, async: false

  alias Dialectic.Accounts.Graph
  alias Dialectic.DbActions.DbWorker
  alias Dialectic.Graph.Vertex
  alias Dialectic.GraphFixtures
  alias Dialectic.Workers.LLMWorker
  alias ReqLLM.StreamResponse.MetadataHandle

  test "defaults to Gemini and persists a terminal stream error without a LiveView subscriber" do
    previous_api_key = System.get_env("GOOGLE_API_KEY")
    System.delete_env("GOOGLE_API_KEY")

    on_exit(fn -> restore_env("GOOGLE_API_KEY", previous_api_key) end)

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
    System.delete_env("GOOGLE_API_KEY")

    on_exit(fn -> restore_env("GOOGLE_API_KEY", previous_api_key) end)

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

  test "persists changing retry states and replaces them after a successful retry" do
    previous_api_key = System.get_env("GOOGLE_API_KEY")
    previous_stream_client = Application.get_env(:dialectic, :llm_stream_client)
    System.put_env("GOOGLE_API_KEY", "test-google-api-key")
    Application.put_env(:dialectic, :llm_stream_client, __MODULE__)

    on_exit(fn ->
      restore_env("GOOGLE_API_KEY", previous_api_key)
      restore_application_env(:llm_stream_client, previous_stream_client)
    end)

    graph =
      GraphFixtures.insert_graph(%{
        title: "worker-retry-#{System.unique_integer([:positive])}"
      })

    {_graph_struct, _digraph} = GraphManager.get_graph(graph.title)
    graph_manager = :global.whereis_name({:graph, graph.title})

    on_exit(fn ->
      if is_pid(graph_manager) and Process.alive?(graph_manager) do
        DynamicSupervisor.terminate_child(GraphSupervisor, graph_manager)
      end
    end)

    answer_node = GraphManager.add_node(graph.title, %Vertex{class: "answer", content: ""})
    topic = "worker-retry-topic-#{System.unique_integer([:positive])}"
    Phoenix.PubSub.subscribe(Dialectic.PubSub, topic)

    request_error = %ReqLLM.Error.API.Request{
      reason: "Provider unavailable",
      status: 503,
      provider_code: 503,
      retryable: true
    }

    stream_error = %ReqLLM.Error.API.Stream{reason: "Stream failed", cause: request_error}

    failing_stream =
      Stream.concat(
        [ReqLLM.StreamChunk.text("Partial response")],
        Stream.map([:fail], fn :fail -> raise stream_error end)
      )

    successful_content = "## Restored title\n\nThe retry completed successfully."

    Process.put(:llm_stream_responses, [
      {:ok, stream_response(failing_stream)},
      {:error, :empty_stream},
      {:ok, stream_response([ReqLLM.StreamChunk.text(successful_content)])}
    ])

    job = worker_job(303, 1, graph.title, answer_node.id, topic)

    assert {:error, ^request_error} = LLMWorker.perform(job)

    overload_message =
      "The AI service is temporarily overloaded. Retrying in #{LLMWorker.provider_retry_delay(job.id, 1)} seconds (attempt 2 of 5)…"

    assert GraphManager.find_node_by_id(graph.title, answer_node.id).content == overload_message

    assert_receive {:llm_request_retrying, ^overload_message, :node_id, node_id}
    assert node_id == answer_node.id

    assert {:error, :empty_stream} = LLMWorker.perform(%{job | attempt: 2})

    generic_message =
      "We hit a temporary problem. Retrying automatically (attempt 3 of 5)…"

    assert GraphManager.find_node_by_id(graph.title, answer_node.id).content == generic_message
    assert_receive {:llm_request_retrying, ^generic_message, :node_id, ^node_id}

    assert :ok = LLMWorker.perform(%{job | attempt: 3})

    assert GraphManager.find_node_by_id(graph.title, answer_node.id).content == successful_content
    assert_receive {:llm_request_complete, ^node_id}
    assert Process.get(:llm_stream_responses) == []
  end

  def stream_text(_model_spec, _context, _options) do
    case Process.get(:llm_stream_responses, []) do
      [response | remaining] ->
        Process.put(:llm_stream_responses, remaining)
        response

      [] ->
        raise "No configured LLM stream response"
    end
  end

  defp worker_job(id, attempt, graph, to_node, topic) do
    %Oban.Job{
      id: id,
      attempt: attempt,
      max_attempts: 5,
      inserted_at: DateTime.utc_now(),
      scheduled_at: DateTime.utc_now(),
      args: %{
        "question" => "Explain",
        "to_node" => to_node,
        "graph" => graph,
        "live_view_topic" => topic
      }
    }
  end

  defp stream_response(stream) do
    {:ok, metadata_handle} = MetadataHandle.start_link(fn -> %{finish_reason: :stop} end)

    %ReqLLM.StreamResponse{
      stream: stream,
      metadata_handle: metadata_handle,
      cancel: fn -> :ok end,
      model: nil,
      context: nil
    }
  end

  defp restore_env(name, nil), do: System.delete_env(name)
  defp restore_env(name, value), do: System.put_env(name, value)

  defp restore_application_env(name, nil), do: Application.delete_env(:dialectic, name)
  defp restore_application_env(name, value), do: Application.put_env(:dialectic, name, value)
end
