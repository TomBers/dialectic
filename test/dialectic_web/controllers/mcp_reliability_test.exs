defmodule DialecticWeb.McpReliabilityTest do
  use DialecticWeb.ConnCase, async: false

  import Dialectic.AccountsFixtures
  import Dialectic.McpFixtures
  alias Dialectic.Accounts.Graph
  alias Dialectic.Integrations.{ChatGrids, Exploration, GridAction, GridActions, GridContent}
  alias Dialectic.Repo

  setup :configure_mcp

  setup %{conn: conn} do
    user = user_fixture()

    api =
      put_req_header(
        conn,
        "authorization",
        "Bearer " <> issue_token(user, "grids:create grids:read grids:append")
      )

    on_exit(fn ->
      for pid <- DynamicSupervisor.which_children(GraphSupervisor) |> Enum.map(&elem(&1, 1)),
          is_pid(pid) do
        DynamicSupervisor.terminate_child(GraphSupervisor, pid)
      end
    end)

    %{user: user, api: api}
  end

  test "completion is persisted before job success and has the same content after restart and pruning",
       %{user: user, api: api} do
    params = %{
      "request_id" => Ecto.UUID.generate(),
      "question" => "How should we compare evidence?"
    }

    {:ok, result} = ChatGrids.start_exploration(user, params)
    operation = Repo.get_by!(GridAction, request_id: params["request_id"])
    job = Repo.get!(Oban.Job, operation.job_id)
    assert :ok = Dialectic.Workers.LocalWorker.perform(job)
    saved = Repo.get!(Graph, result.graph.title)
    receipt = Repo.reload!(operation)
    assert receipt.completed_revision == saved.data_revision
    assert is_integer(receipt.completed_revision)
    assert Enum.find(saved.data["nodes"], &(&1["id"] == "2"))["content"] != ""
    job = job |> Ecto.Changeset.change(state: "completed") |> Repo.update!()
    Repo.delete!(job)

    DynamicSupervisor.terminate_child(
      GraphSupervisor,
      :global.whereis_name({:graph, saved.title})
    )

    status = api |> get(~p"/api/mcp/operations/#{params["request_id"]}") |> json_response(200)

    read =
      api
      |> get(~p"/api/mcp/grids/#{saved.slug}", revision: receipt.completed_revision)
      |> json_response(200)

    assert status["status"] == "completed"
    assert status["snapshot_revision"] == read["snapshot_revision"]
    assert status["answer_node"] == Enum.find(read["nodes"], &(&1["id"] == "2"))
    assert status["answer_node"]["content_status"] == "complete"
    refute Jason.encode!(read) =~ user.email
    GraphManager.set_node_content(saved.title, "2", "User's later revision")
    assert :ok = Dialectic.Workers.LLMWorker.perform(%{job | attempt: 2})
    assert GraphManager.find_node_by_id(saved.title, "2").content == "User's later revision"
    assert Repo.reload!(receipt).completed_revision == receipt.completed_revision

    refute Dialectic.Integrations.ContentReceipts.generation_persisted?(
             saved.title,
             "2",
             job.id + 1
           )

    assert :not_mcp =
             Dialectic.Integrations.ContentReceipts.persist_generation(
               saved.title,
               "2",
               job.id + 1
             )

    assert api |> get(~p"/api/mcp/operations/#{params["request_id"]}") |> json_response(200) ==
             status
  end

  test "cursors stay on the completed revision while a grid changes and cannot expose private history",
       %{user: user, api: api, conn: conn} do
    {:ok, grid} = ChatGrids.create(user, grid_draft())

    append_params = %{
      "request_id" => Ecto.UUID.generate(),
      "parent_node_id" => "2",
      "content" => "Original snapshot"
    }

    {:ok, added} = GridActions.add_idea(user, grid.slug, append_params)
    GraphManager.set_node_content(grid.title, added.node.id, "A later user edit")
    {:ok, replay} = GridActions.add_idea(user, grid.slug, append_params)
    assert replay.node.content == "Original snapshot"
    assert replay.snapshot_revision == added.snapshot_revision

    path = ~p"/api/mcp/grids/#{grid.slug}"
    first = api |> get(path, limit: 1) |> json_response(200)
    original = Repo.get!(Graph, grid.title)

    changed_data =
      Map.update!(original.data, "nodes", fn nodes ->
        Enum.map(nodes, &Map.put(&1, "content", "Changed later"))
      end)

    original
    |> Ecto.Changeset.change(
      data: changed_data,
      data_revision: original.data_revision + 1,
      is_public: true
    )
    |> Repo.update!()

    second = api |> get(path, cursor: first["next_cursor"], limit: 2) |> json_response(200)
    assert second["snapshot_revision"] == first["snapshot_revision"]
    assert Enum.find(second["nodes"], &(&1["id"] == "3"))["content"] == "Original snapshot"
    assert second["next_cursor"] == nil
    assert api |> get(path, cursor: first["next_cursor"] <> "tampered") |> json_response(400)
    {:ok, other} = ChatGrids.create(user, Map.put(grid_draft(), "title", "Other grid"))

    assert api
           |> get(~p"/api/mcp/grids/#{other.slug}", cursor: first["next_cursor"])
           |> json_response(400)

    assert conn |> get(path) |> json_response(200)

    assert conn
           |> get(path, cursor: first["next_cursor"])
           |> json_response(409)
           |> Map.fetch!("code") == "stale_snapshot"
  end

  test "capacity rejects new workflows without losing idempotent receipts", %{
    user: user,
    api: api
  } do
    previous = Application.get_env(:dialectic, :mcp_limits)
    Application.put_env(:dialectic, :mcp_limits, max_active_explorations: 1)

    on_exit(fn ->
      if previous,
        do: Application.put_env(:dialectic, :mcp_limits, previous),
        else: Application.delete_env(:dialectic, :mcp_limits)
    end)

    params = %{"request_id" => Ecto.UUID.generate(), "question" => "What should we learn?"}
    first = api |> post(~p"/api/mcp/explorations/guided", params) |> json_response(200)
    next = Map.put(params, "request_id", Ecto.UUID.generate())
    rejected = api |> post(~p"/api/mcp/explorations/guided", next) |> json_response(429)
    assert rejected["code"] == "too_many_active_operations"
    assert rejected["retryable"]
    assert rejected["retry_after_seconds"] > 0
    refute rejected["request_accepted"]
    assert rejected["request_id"] == next["request_id"]
    assert api |> post(~p"/api/mcp/explorations/guided", params) |> json_response(200) == first
    assert Repo.aggregate(Exploration, :count) == 1
    assert Repo.aggregate(Graph, :count) == 1
    assert {:ok, %{status: "queued"}} = GridActions.get_operation(user, params["request_id"])
  end

  test "structured validation and conflict errors keep the UUID", %{api: api} do
    params = %{"request_id" => Ecto.UUID.generate(), "question" => ""}
    error = api |> post(~p"/api/mcp/explorations", params) |> json_response(422)
    assert error["code"] == "invalid_arguments"
    refute error["retryable"]
    refute error["request_accepted"]
    assert error["request_id"] == params["request_id"]
    valid = Map.put(params, "question", "A real question")
    assert api |> post(~p"/api/mcp/explorations", valid) |> json_response(200)

    conflict =
      api
      |> post(~p"/api/mcp/explorations", Map.put(valid, "question", "Different question"))
      |> json_response(409)

    assert conflict["code"] == "request_conflict"
    assert conflict["request_id"] == params["request_id"]
  end

  test "capabilities are public and reflect enforced limits", %{conn: conn} do
    caps = conn |> get(~p"/api/mcp/capabilities") |> json_response(200)

    assert caps["max_active_explorations"] ==
             Dialectic.Integrations.McpCapabilities.max_active_explorations()

    assert caps["max_active_generations"] == 3
    assert caps["generation_burst_limit"] == 10
    assert caps["suggested_poll_interval_seconds"] == 3
    refute caps["publication_supported"]
    assert caps["revision_bound_reads_supported"]
    assert GridContent.content_status("", "queued") == "placeholder"
    assert GridContent.content_status("", "completed") == "completed_empty"
  end
end
