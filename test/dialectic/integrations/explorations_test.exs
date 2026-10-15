defmodule Dialectic.Integrations.ExplorationsTest do
  use Dialectic.DataCase, async: false

  import Dialectic.AccountsFixtures
  import Dialectic.McpFixtures

  alias Dialectic.Accounts.Graph
  alias Dialectic.Integrations.{ChatGrids, GridAction, GridActions, GridRequest}
  alias Dialectic.Responses.{Prompts, PromptsStructured}

  setup do
    params = %{
      "request_id" => Ecto.UUID.generate(),
      "title" => "MCP exploration #{System.unique_integer([:positive])}",
      "question" => "How can we evaluate a claim?",
      "response_level" => "expert"
    }

    %{user: user_fixture(), params: params}
  end

  test "creates a private native opening answer with the selected response level", %{
    user: user,
    params: params
  } do
    forged =
      Map.merge(params, %{
        "user_id" => user_fixture().id,
        "is_public" => true,
        "answer" => "Do not import this"
      })

    assert {:ok, result} = start(user, forged)
    assert result.status == "queued"
    assert result.graph.user_id == user.id
    refute result.graph.is_public
    assert result.graph.prompt_mode == "expert"

    assert result.node == %{
             id: "1",
             parent_node_id: nil,
             content: "## " <> params["question"],
             class: "origin"
           }

    assert result.answer_node == %{id: "2", parent_node_id: "1", content: "", class: "answer"}
    answer = GraphManager.find_node_by_id(result.graph.title, "2")
    assert answer.prompt_kind == "initial_explainer"
    assert answer.response_level == "expert"
    assert answer.user == user.email
    job = Repo.one!(Oban.Job)
    assert job.args["instruction"] == Prompts.initial_explainer("", result.node.content, :expert)
    assert job.args["system_prompt"] == PromptsStructured.system_preamble(:expert)
    assert job.args["response_level"] == "expert"

    assert job.args["actor_key"] ==
             :crypto.hash(:sha256, "user:#{user.email}") |> Base.url_encode64(padding: false)

    assert job.args["instruction"] =~ "exactly 3 numbered questions"
    assert length(Repo.get!(Graph, result.graph.title).data["nodes"]) == 2
  end

  test "retries are idempotent and conflict with changed questions, levels and imports", %{
    user: user,
    params: params
  } do
    assert {:ok, first} = start(user, params)

    results =
      1..4
      |> Task.async_stream(fn _ -> ChatGrids.start_exploration(user, params) end)
      |> Enum.to_list()

    assert Enum.all?(results, fn {:ok, {:ok, result}} ->
             result.graph.title == first.graph.title
           end)

    assert Repo.aggregate(Graph, :count) == 1
    assert Repo.aggregate(Oban.Job, :count) == 1
    assert Repo.aggregate(GridAction, :count) == 1
    assert Repo.aggregate(GridRequest, :count) == 1

    assert {:error, :request_conflict} =
             ChatGrids.start_exploration(user, %{params | "question" => "Something else?"})

    assert {:error, :request_conflict} =
             ChatGrids.start_exploration(user, %{params | "response_level" => "university"})

    assert {:error, :request_conflict} =
             ChatGrids.create(user, Map.put(grid_draft(), "request_id", params["request_id"]))

    assert Repo.aggregate(Oban.Job, :count) == 1
  end

  test "operation reads expose partial text without writing or enqueueing", %{
    user: user,
    params: params
  } do
    {:ok, result} = start(user, params)
    job = Repo.one!(Oban.Job)
    job |> Ecto.Changeset.change(state: "executing") |> Repo.update!()
    GraphManager.set_node_content(result.graph.title, "2", "A partial response")
    assert {:ok, progress} = GridActions.get_operation(user, params["request_id"])
    assert progress.status == "generating"
    assert progress.answer_node.content == "A partial response"
    GraphManager.update_graph_struct(result.graph.title, %{result.graph | is_locked: true})
    assert {:ok, _} = GridActions.get_operation(user, params["request_id"])
    assert Repo.aggregate(Oban.Job, :count) == 1
    assert Repo.aggregate(GridAction, :count) == 1
  end

  test "terminal state survives job pruning and graph process restart", %{
    user: user,
    params: params
  } do
    {:ok, result} = start(user, params)
    job = Repo.one!(Oban.Job)
    GraphManager.set_node_content(result.graph.title, "2", "A completed answer")
    {_, live_graph} = GraphManager.get_graph(result.graph.title)
    data = Dialectic.Graph.Serialise.graph_to_json(live_graph)
    result.graph |> Ecto.Changeset.change(data: data) |> Repo.update!()
    job |> Ecto.Changeset.change(state: "completed") |> Repo.update!() |> Repo.delete!()
    stop_graph(result.graph.title)
    assert {:ok, completed} = GridActions.get_operation(user, params["request_id"])
    assert completed.status == "completed"
    assert completed.answer_node.content == "A completed answer"
    assert {:ok, replay} = ChatGrids.start_exploration(user, params)
    assert replay.status == "completed"
    assert Repo.aggregate(Oban.Job, :count) == 0
  end

  test "failed operations survive pruning and missing unfinished jobs stay unknown", %{
    user: user,
    params: params
  } do
    {:ok, _} = start(user, params)
    job = Repo.one!(Oban.Job)
    job |> Ecto.Changeset.change(state: "retryable") |> Repo.update!()
    assert {:ok, %{status: "queued"}} = GridActions.get_operation(user, params["request_id"])
    job |> Ecto.Changeset.change(state: "cancelled") |> Repo.update!() |> Repo.delete!()
    assert {:ok, %{status: "failed"}} = GridActions.get_operation(user, params["request_id"])
    next = %{params | "request_id" => Ecto.UUID.generate()}
    {:ok, _} = start(user, next)
    Repo.one!(Oban.Job) |> Repo.delete!()
    assert {:ok, %{status: "unknown"}} = GridActions.get_operation(user, next["request_id"])
  end

  test "ownership and deletion are enforced on progress and retries", %{
    user: user,
    params: params
  } do
    {:ok, result} = start(user, params)
    assert {:error, :not_found} = GridActions.get_operation(user_fixture(), params["request_id"])
    assert {:error, :not_found} = GridActions.get_operation(user, "invalid")
    GraphManager.delete_node(result.graph.title, "2")
    assert {:error, :unavailable} = GridActions.get_operation(user, params["request_id"])
    assert {:error, :unavailable} = ChatGrids.start_exploration(user, params)
    result.graph |> Ecto.Changeset.change(is_deleted: true) |> Repo.update!()
    assert {:error, :not_found} = GridActions.get_operation(user, params["request_id"])
    assert {:error, :unavailable} = ChatGrids.start_exploration(user, params)
    Repo.delete!(Repo.get!(Graph, result.graph.title))
    assert {:error, :not_found} = GridActions.get_operation(user, params["request_id"])
    assert {:error, :unavailable} = ChatGrids.start_exploration(user, params)
  end

  test "invalid inputs never create a grid or queue a job", %{user: user, params: params} do
    for changed <- [
          %{"question" => " "},
          %{"question" => String.duplicate("x", 4001)},
          %{"title" => " "},
          %{"title" => String.duplicate("x", 141)},
          %{"response_level" => "invalid"},
          %{"request_id" => "invalid"},
          %{"question" => nil},
          %{"title" => ["invalid"]}
        ] do
      assert {:error, _} = ChatGrids.start_exploration(user, Map.merge(params, changed))
    end

    assert Repo.aggregate(Graph, :count) == 0
    assert Repo.aggregate(Oban.Job, :count) == 0
    assert Repo.aggregate(GridRequest, :count) == 0
  end

  test "an existing append request cannot be reused to create a new exploration", %{
    user: user,
    params: params
  } do
    {:ok, graph} = ChatGrids.create(user, grid_draft())
    on_exit(fn -> stop_graph(graph.title) end)

    {:ok, _} =
      GridActions.add_idea(user, graph.slug, %{
        "request_id" => params["request_id"],
        "parent_node_id" => "1",
        "content" => "My idea"
      })

    assert {:error, :request_conflict} = ChatGrids.start_exploration(user, params)
    assert Repo.aggregate(Graph, :count) == 1
    assert Repo.aggregate(GridAction, :count) == 1
    assert Repo.aggregate(GridRequest, :count) == 1
    assert Repo.aggregate(Oban.Job, :count) == 0
  end

  defp start(user, params) do
    result = ChatGrids.start_exploration(user, params)

    if match?({:ok, _}, result) do
      {:ok, operation} = result
      on_exit(fn -> stop_graph(operation.graph.title) end)
    end

    result
  end

  defp stop_graph(title) do
    case :global.whereis_name({:graph, title}) do
      pid when is_pid(pid) -> DynamicSupervisor.terminate_child(GraphSupervisor, pid)
      _ -> :ok
    end
  end
end
