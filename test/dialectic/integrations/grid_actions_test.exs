defmodule Dialectic.Integrations.GridActionsTest do
  use Dialectic.DataCase, async: false

  import Dialectic.AccountsFixtures
  import Dialectic.McpFixtures

  alias Dialectic.Accounts.Graph
  alias Dialectic.Graph.Vertex
  alias Dialectic.Integrations.{ChatGrids, GridAction, GridActions}
  alias Dialectic.Responses.{Prompts, RequestQueue}

  setup do
    user = user_fixture()
    draft = Map.put(grid_draft(), "title", "MCP actions #{System.unique_integer([:positive])}")
    {:ok, graph} = ChatGrids.create(user, draft)
    params = %{"request_id" => Ecto.UUID.generate(), "node_id" => "2", "action" => "clarify"}

    on_exit(fn ->
      case :global.whereis_name({:graph, graph.title}) do
        pid when is_pid(pid) -> DynamicSupervisor.terminate_child(GraphSupervisor, pid)
        _ -> :ok
      end
    end)

    %{user: user, graph: graph, params: params}
  end

  test "appends durably using the existing prompt, keeps live edits, and does not change visibility",
       context do
    %{user: user, graph: graph, params: params} = context
    graph |> Ecto.Changeset.change(is_public: true) |> Repo.update!()
    {_stored, original_digraph} = GraphManager.get_graph(graph.title)
    GraphManager.set_node_content(graph.title, "2", "An unsaved idea to clarify")
    Phoenix.PubSub.subscribe(Dialectic.PubSub, "graph_update:#{graph.title}")

    assert {:ok, result} = GridActions.apply(user, graph.slug, params)
    assert result.status == "queued"
    assert result.graph.is_public
    assert result.node == %{id: "3", parent_node_id: "2", class: "clarify", content: ""}
    assert_receive {:other_user_change, _pid}
    assert {_stored, ^original_digraph} = GraphManager.get_graph(graph.title)
    saved = Repo.get!(Graph, graph.title)
    assert saved.is_public
    assert saved.user_id == user.id

    assert Enum.find(saved.data["nodes"], &(&1["id"] == "2"))["content"] ==
             "An unsaved idea to clarify"

    assert Enum.any?(
             saved.data["edges"],
             &(&1["data"]["source"] == "2" and &1["data"]["target"] == "3")
           )

    request = Repo.one!(GridAction)
    job = Repo.get!(Oban.Job, request.job_id)

    assert job.args["instruction"] ==
             Prompts.clarify("What would change our minds?", "An unsaved idea to clarify")

    assert job.args["to_node"] == "3"
    assert job.args["graph"] == graph.title
    assert job.args["response_level"] == "university"
  end

  test "authored ideas preserve exact text, live edits and visibility without queueing AI", %{
    user: user,
    graph: graph
  } do
    graph |> Ecto.Changeset.change(is_public: true) |> Repo.update!()
    GraphManager.get_graph(graph.title)
    GraphManager.set_node_content(graph.title, "2", "An unsaved change")
    content = "  My **own** idea.\n\nKeep this wording.  "

    params = %{
      "request_id" => Ecto.UUID.generate(),
      "parent_node_id" => "2",
      "content" => content,
      "user_id" => user_fixture().id,
      "is_public" => false,
      "action" => "clarify"
    }

    assert {:ok, result} = GridActions.add_idea(user, graph.slug, params)
    assert result.status == "completed"
    assert result.node == %{id: "3", parent_node_id: "2", class: "user", content: content}
    assert result.graph.is_public
    node = GraphManager.find_node_by_id(graph.title, "3")
    assert node.user == user.email
    assert node.prompt_kind == nil
    assert Enum.map(node.parents, & &1.id) == ["2"]
    stored = Repo.get!(Graph, graph.title)
    assert Enum.find(stored.data["nodes"], &(&1["id"] == "3"))["content"] == content
    assert Enum.find(stored.data["nodes"], &(&1["id"] == "2"))["content"] == "An unsaved change"

    assert Enum.any?(
             stored.data["edges"],
             &(&1["data"]["source"] == "2" and &1["data"]["target"] == "3")
           )

    assert Repo.one!(GridAction).job_id == nil
    assert Repo.aggregate(Oban.Job, :count) == 0
  end

  test "questions save a question and connected answer, using the existing response prompt", %{
    user: user,
    graph: graph
  } do
    params = %{
      "request_id" => Ecto.UUID.generate(),
      "parent_node_id" => "2",
      "kind" => "question",
      "content" => "  How could we test this?\n"
    }

    assert {:ok, result} = GridActions.add_idea(user, graph.slug, params)
    assert result.status == "queued"

    assert result.node == %{
             id: "3",
             parent_node_id: "2",
             class: "question",
             content: params["content"]
           }

    assert result.answer_node == %{id: "4", parent_node_id: "3", class: "answer", content: ""}
    question = GraphManager.find_node_by_id(graph.title, "3")
    answer = GraphManager.find_node_by_id(graph.title, "4")
    assert question.prompt_kind == "question"
    assert answer.prompt_kind == "answer"
    assert Enum.map(answer.parents, & &1.id) == ["3"]
    stored = Repo.get!(Graph, graph.title)
    assert length(stored.data["nodes"]) == 4

    assert Enum.any?(
             stored.data["edges"],
             &(&1["data"]["source"] == "2" and &1["data"]["target"] == "3")
           )

    assert Enum.any?(
             stored.data["edges"],
             &(&1["data"]["source"] == "3" and &1["data"]["target"] == "4")
           )

    request = Repo.one!(GridAction)
    assert request.node_id == "3"
    assert request.answer_node_id == "4"
    job = Repo.get!(Oban.Job, request.job_id)
    assert job.args["to_node"] == "4"
    context = GraphManager.build_context(graph.title, question)
    assert context =~ "Look for counterexamples"
    assert context =~ "What would change our minds?"
    assert job.args["instruction"] == Prompts.explain(context, params["content"])

    assert :ok = Dialectic.Workers.LocalWorker.perform(job)
    job |> Ecto.Changeset.change(state: "completed") |> Repo.update!()
    assert {:ok, completed} = GridActions.add_idea(user, graph.slug, params)
    assert completed.status == "completed"
    assert completed.node.content == params["content"]
    assert completed.answer_node.content == job.args["instruction"]
    assert Repo.aggregate(Oban.Job, :count) == 1
  end

  test "question retries preserve both IDs across concurrent calls and restarts", %{
    user: user,
    graph: graph
  } do
    params = %{
      "request_id" => Ecto.UUID.generate(),
      "parent_node_id" => "2",
      "kind" => "question",
      "content" => "Why?"
    }

    results =
      1..4
      |> Task.async_stream(fn _ -> GridActions.add_idea(user, graph.slug, params) end)
      |> Enum.map(fn {:ok, {:ok, result}} -> {result.node.id, result.answer_node.id} end)

    assert Enum.uniq(results) == [{"3", "4"}]

    DynamicSupervisor.terminate_child(
      GraphSupervisor,
      :global.whereis_name({:graph, graph.title})
    )

    assert {:ok, result} = GridActions.add_idea(user, graph.slug, params)
    assert {result.node.id, result.answer_node.id} == {"3", "4"}
    assert Repo.aggregate(Oban.Job, :count) == 1
    assert Repo.aggregate(GridAction, :count) == 1

    for changed <- [%{"kind" => "comment"}, %{"content" => "How?"}, %{"parent_node_id" => "1"}] do
      assert {:error, :request_conflict} =
               GridActions.add_idea(user, graph.slug, Map.merge(params, changed))
    end

    GraphManager.delete_node(graph.title, result.answer_node.id)
    assert {:error, :unavailable} = GridActions.add_idea(user, graph.slug, params)
    assert Repo.aggregate(Oban.Job, :count) == 1
    assert length(Repo.get!(Graph, graph.title).data["nodes"]) == 4
  end

  test "question status reflects failures and neither part is recreated after deletion", %{
    user: user,
    graph: graph
  } do
    params = %{
      "request_id" => Ecto.UUID.generate(),
      "parent_node_id" => "2",
      "kind" => "question",
      "content" => "Why?"
    }

    {:ok, result} = GridActions.add_idea(user, graph.slug, params)
    job = Repo.one!(Oban.Job)
    job |> Ecto.Changeset.change(state: "discarded") |> Repo.update!()

    assert {:ok, %{status: "failed", answer_node: %{id: "4"}}} =
             GridActions.add_idea(user, graph.slug, params)

    GraphManager.delete_node(graph.title, result.node.id)
    assert {:error, :unavailable} = GridActions.add_idea(user, graph.slug, params)
    assert Repo.aggregate(Oban.Job, :count) == 1
  end

  test "comments do not generate even when phrased as questions, and kind is validated", %{
    user: user,
    graph: graph
  } do
    params = %{
      "request_id" => Ecto.UUID.generate(),
      "parent_node_id" => "2",
      "kind" => "comment",
      "content" => "Is this enough?"
    }

    for kind <- [nil, "answer", %{}, 123] do
      assert {:error, :invalid_kind} =
               GridActions.add_idea(user, graph.slug, %{params | "kind" => kind})
    end

    assert {:ok, result} = GridActions.add_idea(user, graph.slug, params)
    assert result.status == "completed"
    assert result.node.class == "user"
    refute Map.has_key?(result, :answer_node)
    assert Repo.aggregate(Oban.Job, :count) == 0
    assert {:ok, retry} = GridActions.add_idea(user, graph.slug, Map.delete(params, "kind"))
    assert retry.node == result.node
    assert retry.status == result.status
    assert retry.request_id == result.request_id

    assert {:error, :request_conflict} =
             GridActions.add_idea(user, graph.slug, %{params | "kind" => "question"})
  end

  test "authored nodes support further authored and thinking-tool branches", %{
    user: user,
    graph: graph,
    params: action
  } do
    params = %{
      "request_id" => Ecto.UUID.generate(),
      "parent_node_id" => "1",
      "content" => "My starting idea"
    }

    assert {:ok, first} = GridActions.add_idea(user, graph.slug, params)

    assert {:ok, second} =
             GridActions.add_idea(user, graph.slug, %{
               params
               | "request_id" => Ecto.UUID.generate(),
                 "parent_node_id" => first.node.id,
                 "content" => "A related idea"
             })

    assert second.node.parent_node_id == first.node.id
    refute second.graph.is_public
    assert Repo.aggregate(Oban.Job, :count) == 0

    assert {:ok, generated} =
             GridActions.apply(user, graph.slug, %{action | "node_id" => second.node.id})

    assert generated.status == "queued"
    assert generated.node.parent_node_id == second.node.id
    assert Repo.one!(Oban.Job).args["instruction"] =~ "A related idea"
  end

  test "authored retries survive concurrent calls and restart, comparing original text not edited nodes",
       %{user: user, graph: graph, params: action} do
    params = %{
      "request_id" => Ecto.UUID.generate(),
      "parent_node_id" => "2",
      "content" => "My idea"
    }

    results =
      1..4
      |> Task.async_stream(fn _ -> GridActions.add_idea(user, graph.slug, params) end)
      |> Enum.map(fn {:ok, {:ok, result}} -> result.node.id end)

    assert Enum.uniq(results) == ["3"]

    DynamicSupervisor.terminate_child(
      GraphSupervisor,
      :global.whereis_name({:graph, graph.title})
    )

    assert {:ok, %{node: %{id: "3"}}} = GridActions.add_idea(user, graph.slug, params)
    GraphManager.set_node_content(graph.title, "3", "Later edit in the app")

    assert {:ok, %{node: %{content: "Later edit in the app"}}} =
             GridActions.add_idea(user, graph.slug, params)

    for changed <- [
          %{"content" => "Different"},
          %{"content" => "My idea "},
          %{"parent_node_id" => "1"}
        ] do
      assert {:error, :request_conflict} =
               GridActions.add_idea(user, graph.slug, Map.merge(params, changed))
    end

    assert {:error, :request_conflict} =
             GridActions.apply(user, graph.slug, %{action | "request_id" => params["request_id"]})

    GraphManager.delete_node(graph.title, "3")
    assert {:error, :unavailable} = GridActions.add_idea(user, graph.slug, params)
    assert Repo.aggregate(GridAction, :count) == 1
    assert Repo.aggregate(Oban.Job, :count) == 0
  end

  test "authored ideas enforce ownership, locks, target validity and input limits", %{
    user: user,
    graph: graph
  } do
    params = %{
      "request_id" => Ecto.UUID.generate(),
      "parent_node_id" => "2",
      "content" => "My idea"
    }

    for content <- [nil, "", " \n\t", String.duplicate("a", 4001), %{}, 12] do
      assert {:error, :invalid_content} =
               GridActions.add_idea(user, graph.slug, %{params | "content" => content})
    end

    for invalid <- [%{"request_id" => "bad"}, %{"parent_node_id" => nil}] do
      assert {:error, :invalid_action} =
               GridActions.add_idea(user, graph.slug, Map.merge(params, invalid))
    end

    assert {:error, :not_found} = GridActions.add_idea(user_fixture(), graph.slug, params)
    refute GraphManager.exists?(graph.title)
    GraphManager.get_graph(graph.title)
    graph |> Ecto.Changeset.change(is_locked: true) |> Repo.update!()
    assert {:error, :locked} = GridActions.add_idea(user, graph.slug, params)
    graph |> Repo.reload!() |> Ecto.Changeset.change(is_locked: false) |> Repo.update!()

    assert {:error, :invalid_node} =
             GridActions.add_idea(user, graph.slug, %{params | "parent_node_id" => "missing"})

    for fields <- [
          %{compound: true},
          %{compound: false, content: ""},
          %{deleted: true, content: "Deleted"}
        ] do
      GraphManager.update_vertex_fields(graph.title, "2", fields)
      assert {:error, :invalid_node} = GridActions.add_idea(user, graph.slug, params)
    end

    assert Repo.aggregate(GridAction, :count) == 0
    assert Repo.aggregate(Oban.Job, :count) == 0
    assert length(Repo.get!(Graph, graph.title).data["nodes"]) == 2
  end

  test "identical concurrent retries and a process restart never enqueue twice", %{
    user: user,
    graph: graph,
    params: params
  } do
    results =
      1..4
      |> Task.async_stream(fn _ -> GridActions.apply(user, graph.slug, params) end)
      |> Enum.map(fn {:ok, {:ok, result}} -> result.node.id end)

    assert Enum.uniq(results) == ["3"]
    assert Repo.aggregate(GridAction, :count) == 1
    assert Repo.aggregate(Oban.Job, :count) == 1

    DynamicSupervisor.terminate_child(
      GraphSupervisor,
      :global.whereis_name({:graph, graph.title})
    )

    assert {:ok, result} = GridActions.apply(user, graph.slug, params)
    assert result.node.id == "3"
    assert Repo.aggregate(Oban.Job, :count) == 1

    assert {:error, :request_conflict} =
             GridActions.apply(user, graph.slug, %{params | "action" => "assumptions"})

    assert {:error, :request_conflict} =
             GridActions.apply(user, graph.slug, %{params | "node_id" => "1"})
  end

  test "reports generated output and job status without generating again", %{
    user: user,
    graph: graph,
    params: params
  } do
    assert {:ok, result} = GridActions.apply(user, graph.slug, params)
    request = Repo.one!(GridAction)
    job = Repo.get!(Oban.Job, request.job_id)
    assert :ok = Dialectic.Workers.LocalWorker.perform(job)
    job |> Ecto.Changeset.change(state: "completed") |> Repo.update!()
    assert {:ok, complete} = GridActions.apply(user, graph.slug, params)
    assert complete.status == "completed"
    assert complete.node.id == result.node.id
    assert complete.node.content == job.args["question"]

    for {state, expected} <- [
          {"executing", "generating"},
          {"retryable", "queued"},
          {"cancelled", "failed"},
          {"discarded", "failed"}
        ] do
      job |> Ecto.Changeset.change(state: state) |> Repo.update!()
      assert {:ok, %{status: ^expected}} = GridActions.apply(user, graph.slug, params)
    end

    Repo.delete!(job)
    assert {:ok, %{status: "unknown"}} = GridActions.apply(user, graph.slug, params)
    assert Repo.aggregate(GridAction, :count) == 1
  end

  test "each supported action uses its own prompt and adds one connected node", %{
    user: user,
    graph: graph,
    params: params
  } do
    for action <-
          ~w(clarify assumptions counterexample implications blind_spots says_who who_disagrees steel_man what_if) do
      action_params = %{params | "request_id" => Ecto.UUID.generate(), "action" => action}
      assert {:ok, result} = GridActions.apply(user, graph.slug, action_params)
      assert result.node.class == action
      request = Repo.get_by!(GridAction, request_id: action_params["request_id"])
      assert Repo.get!(Oban.Job, request.job_id).args["instruction"] != ""
      node = GraphManager.find_node_by_id(graph.title, result.node.id)
      assert Enum.map(node.parents, & &1.id) == ["2"]
    end

    assert Repo.aggregate(GridAction, :count) == 9
  end

  test "only the owner may append, including to public grids", %{
    user: user,
    graph: graph,
    params: params
  } do
    assert {:error, :not_found} = GridActions.apply(user_fixture(), graph.slug, params)
    refute GraphManager.exists?(graph.title)
    graph |> Ecto.Changeset.change(is_public: true) |> Repo.update!()
    assert {:error, :not_found} = GridActions.apply(user_fixture(), graph.slug, params)
    graph |> Ecto.Changeset.change(is_deleted: true) |> Repo.update!()
    assert {:error, :not_found} = GridActions.apply(user, graph.slug, params)
    assert Repo.aggregate(GridAction, :count) == 0
  end

  test "locks and stale snapshots reject writes without side effects", %{
    user: user,
    graph: graph,
    params: params
  } do
    GraphManager.get_graph(graph.title)
    graph |> Ecto.Changeset.change(is_locked: true) |> Repo.update!()
    assert {:error, :locked} = GridActions.apply(user, graph.slug, params)

    graph
    |> Repo.reload!()
    |> Ecto.Changeset.change(is_locked: false, data_revision: graph.data_revision + 1)
    |> Repo.update!()

    assert {:error, :stale} = GridActions.apply(user, graph.slug, params)
    assert GraphManager.find_node_by_id(graph.title, "3") == nil
    assert Repo.aggregate(GridAction, :count) == 0
    assert Repo.aggregate(Oban.Job, :count) == 0
  end

  test "invalid, deleted, empty, and compound targets cannot generate", %{
    user: user,
    graph: graph,
    params: params
  } do
    for invalid <- [%{"request_id" => "bad"}, %{"action" => "delete"}, %{"node_id" => nil}] do
      assert {:error, :invalid_action} =
               GridActions.apply(user, graph.slug, Map.merge(params, invalid))
    end

    assert {:error, :invalid_node} =
             GridActions.apply(user, graph.slug, %{params | "node_id" => "missing"})

    for fields <- [
          %{deleted: true},
          %{deleted: false, compound: true},
          %{compound: false, content: ""}
        ] do
      GraphManager.update_vertex_fields(graph.title, "2", fields)
      assert {:error, :invalid_node} = GridActions.apply(user, graph.slug, params)
    end

    assert Repo.aggregate(GridAction, :count) == 0
    assert Repo.aggregate(Oban.Job, :count) == 0
  end

  test "a removed result is not silently recreated on retry", %{
    user: user,
    graph: graph,
    params: params
  } do
    {:ok, result} = GridActions.apply(user, graph.slug, params)
    GraphManager.delete_node(graph.title, result.node.id)
    assert {:error, :unavailable} = GridActions.apply(user, graph.slug, params)
    assert Repo.aggregate(GridAction, :count) == 1
    assert Repo.aggregate(Oban.Job, :count) == 1
  end

  test "rate rejection can be returned inside the graph process without calling itself", %{
    graph: graph,
    user: user
  } do
    GraphManager.get_graph(graph.title)

    params =
      RequestQueue.build_params(
        "question",
        "system",
        %Vertex{id: "2", user: user.email},
        graph.title,
        "graph_update:#{graph.title}",
        []
      )

    for index <- 1..3 do
      assert {:ok, _} = RequestQueue.run_llm(%{params | to_node: "pending-#{index}"})
    end

    caller = self()

    :sys.replace_state(GraphManager.via_tuple(graph.title), fn state ->
      result = Repo.transact(fn -> RequestQueue.run_llm(params, notify_rejection: false) end)
      send(caller, {:admission, result})
      state
    end)

    assert_receive {:admission, {:error, :too_many_active_requests}}
    assert GraphManager.find_node_by_id(graph.title, "2").content == "Look for counterexamples"
  end
end
