defmodule Dialectic.Responses.RequestQueueWorkerTest do
  use DialecticWeb.ConnCase, async: false
  use Oban.Testing, repo: Dialectic.Repo

  import Ecto.Query

  alias Dialectic.Repo
  alias Dialectic.Responses.{ModeServer, PromptsStructured, RequestQueue}
  alias Dialectic.Workers.{LLMWorker, LocalWorker}

  setup do
    previous_config = Application.get_env(:dialectic, :llm_admission)

    Application.put_env(:dialectic, :llm_admission,
      max_active_per_actor: 3,
      max_requests_per_minute: 10
    )

    on_exit(fn ->
      if previous_config do
        Application.put_env(:dialectic, :llm_admission, previous_config)
      else
        Application.delete_env(:dialectic, :llm_admission)
      end
    end)

    :ok
  end

  describe "RequestQueue.add/5 (test env)" do
    test "enqueues LocalWorker job with core args; optional prompt args are ignored" do
      vertex = %Elixir.Dialectic.Graph.Vertex{id: "1", user: "reader@example.com"}

      RequestQueue.add("What is dialectics?", "SYSTEM", vertex, "GraphX", "topic-x")

      assert_enqueued(
        worker: LocalWorker,
        queue: "api_request",
        args: %{
          "question" => "What is dialectics?",
          "to_node" => "1",
          "graph" => "GraphX",
          "live_view_topic" => "topic-x"
        }
      )

      worker = Oban.Worker.to_string(LocalWorker)
      job = Repo.one!(from job in Oban.Job, where: job.worker == ^worker)

      assert is_binary(job.args["actor_key"])
      refute job.args["actor_key"] =~ "reader@example.com"
    end

    test "snapshots a progressively larger output budget for each answer level" do
      request_id = System.unique_integer([:positive])

      for mode <- ModeServer.supported_modes() do
        graph = "BudgetGraph-#{request_id}-#{mode}"
        :ok = ModeServer.set_mode(graph, mode)
        on_exit(fn -> ModeServer.delete_mode(graph) end)

        assert {:ok, job} =
                 RequestQueue.add(
                   "Explain this",
                   "SYSTEM",
                   %Dialectic.Graph.Vertex{id: "node-#{mode}", user: "anonymous"},
                   graph,
                   "topic-#{mode}"
                 )

        persisted_job = Repo.get!(Oban.Job, job.id)
        assert persisted_job.args["response_level"] == Atom.to_string(mode)
        assert persisted_job.args["max_tokens"] == PromptsStructured.max_output_tokens(mode)
      end
    end

    test "uses the supplied mode snapshot even if the graph mode changes" do
      graph = "SnapshotGraph-#{System.unique_integer([:positive])}"
      :ok = ModeServer.set_mode(graph, :simple)
      on_exit(fn -> ModeServer.delete_mode(graph) end)

      assert {:ok, job} =
               RequestQueue.add(
                 "Explain this",
                 PromptsStructured.system_preamble(:expert),
                 %Dialectic.Graph.Vertex{id: "snapshot-node", user: "anonymous"},
                 graph,
                 "snapshot-topic",
                 mode: :expert
               )

      persisted_job = Repo.get!(Oban.Job, job.id)
      assert persisted_job.args["system_prompt"] =~ "Complexity level: Expert"
      assert persisted_job.args["response_level"] == "expert"
      assert persisted_job.args["max_tokens"] == PromptsStructured.max_output_tokens(:expert)
    end

    test "infers the compatibility mode from the supplied application prompt" do
      graph = "PromptModeGraph-#{System.unique_integer([:positive])}"
      :ok = ModeServer.set_mode(graph, :simple)
      on_exit(fn -> ModeServer.delete_mode(graph) end)

      assert {:ok, job} =
               RequestQueue.add(
                 "Explain this",
                 PromptsStructured.system_preamble(:expert),
                 %Dialectic.Graph.Vertex{id: "prompt-mode-node", user: "anonymous"},
                 graph,
                 "prompt-mode-topic"
               )

      persisted_job = Repo.get!(Oban.Job, job.id)
      assert persisted_job.args["response_level"] == "expert"
      assert persisted_job.args["max_tokens"] == PromptsStructured.max_output_tokens(:expert)
    end

    test "uses the stable anonymous session actor instead of the PubSub topic" do
      actor_id = "session-#{System.unique_integer([:positive])}"

      RequestQueue.add(
        "First",
        "SYSTEM",
        %Dialectic.Graph.Vertex{id: "anonymous-1", user: "anonymous"},
        "GraphX",
        {"topic-one", actor_id}
      )

      RequestQueue.add(
        "Second",
        "SYSTEM",
        %Dialectic.Graph.Vertex{id: "anonymous-2", user: "anonymous"},
        "GraphY",
        {"topic-two", actor_id}
      )

      worker = Oban.Worker.to_string(LocalWorker)
      jobs = Repo.all(from job in Oban.Job, where: job.worker == ^worker, order_by: job.id)

      assert [first_job, second_job] = jobs
      assert first_job.args["actor_key"] == second_job.args["actor_key"]
      refute first_job.args["actor_key"] =~ actor_id
    end
  end

  describe "RequestQueue.run_llm/1 admission controls" do
    test "limits active requests per actor while allowing other actors" do
      Application.put_env(:dialectic, :llm_admission,
        max_active_per_actor: 2,
        max_requests_per_minute: 10
      )

      actor_key = "actor-#{System.unique_integer([:positive])}"
      topic = "topic-#{System.unique_integer([:positive])}"
      Phoenix.PubSub.subscribe(Dialectic.PubSub, topic)

      assert {:ok, _job} = RequestQueue.run_llm(llm_params(actor_key, topic, "node-1"))
      assert {:ok, _job} = RequestQueue.run_llm(llm_params(actor_key, topic, "node-2"))

      assert {:error, :too_many_active_requests} =
               RequestQueue.run_llm(llm_params(actor_key, topic, "node-3"))

      assert_receive {:stream_error, message, :node_id, "node-3"}
      assert message =~ "2 AI requests in progress"
      assert_receive {:llm_request_complete, "node-3"}

      other_actor = "other-#{System.unique_integer([:positive])}"
      assert {:ok, _job} = RequestQueue.run_llm(llm_params(other_actor, topic, "node-4"))

      assert llm_job_count() == 3
    end

    test "rate limits rapid requests for the same actor" do
      Application.put_env(:dialectic, :llm_admission,
        max_active_per_actor: 10,
        max_requests_per_minute: 2
      )

      actor_key = "rate-#{System.unique_integer([:positive])}"
      topic = "topic-#{System.unique_integer([:positive])}"
      Phoenix.PubSub.subscribe(Dialectic.PubSub, topic)

      assert {:ok, _job} = RequestQueue.run_llm(llm_params(actor_key, topic, "rate-node-1"))
      assert {:ok, _job} = RequestQueue.run_llm(llm_params(actor_key, topic, "rate-node-2"))

      assert {:error, :rate_limited} =
               RequestQueue.run_llm(llm_params(actor_key, topic, "rate-node-3"))

      assert_receive {:stream_error, message, :node_id, "rate-node-3"}
      assert message =~ "too quickly"
      assert_receive {:llm_request_complete, "rate-node-3"}

      assert llm_job_count() == 2
    end

    test "reports queued and executing job counts from Oban" do
      actor_key = "metrics-#{System.unique_integer([:positive])}"
      topic = "topic-#{System.unique_integer([:positive])}"

      assert {:ok, _job} = RequestQueue.run_llm(llm_params(actor_key, topic, "metrics-node-1"))
      assert {:ok, _job} = RequestQueue.run_llm(llm_params(actor_key, topic, "metrics-node-2"))

      handler_id = {__MODULE__, self(), make_ref()}

      :ok =
        :telemetry.attach(
          handler_id,
          [:dialectic, :llm, :queue],
          fn event, measurements, metadata, pid ->
            send(pid, {:queue_telemetry, event, measurements, metadata})
          end,
          self()
        )

      on_exit(fn -> :telemetry.detach(handler_id) end)

      assert :ok = DialecticWeb.Telemetry.measure_llm_queue()

      assert_receive {:queue_telemetry, [:dialectic, :llm, :queue], %{queued: 2, executing: 0},
                      %{}}
    end

    test "duplicate jobs remain idempotent when the actor is at the active limit" do
      Application.put_env(:dialectic, :llm_admission,
        max_active_per_actor: 1,
        max_requests_per_minute: 10
      )

      actor_key = "duplicate-#{System.unique_integer([:positive])}"
      topic = "topic-#{System.unique_integer([:positive])}"
      params = llm_params(actor_key, topic, "same-node")

      assert {:ok, first_job} = RequestQueue.run_llm(params)
      assert {:ok, duplicate_job} = RequestQueue.run_llm(params)
      assert duplicate_job.conflict?
      assert duplicate_job.id == first_job.id
      assert llm_job_count() == 1
    end
  end

  defp llm_params(actor_key, topic, node_id) do
    %{
      instruction: "Explain this",
      system_prompt: "Be concise",
      question: "Explain this",
      to_node: node_id,
      graph: "AdmissionGraph",
      module: nil,
      live_view_topic: topic,
      actor_key: actor_key
    }
  end

  defp llm_job_count do
    worker = Oban.Worker.to_string(LLMWorker)
    Repo.aggregate(from(job in Oban.Job, where: job.worker == ^worker), :count)
  end
end
