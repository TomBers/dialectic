defmodule DialecticWeb.McpVisibilityTest do
  use DialecticWeb.ConnCase, async: false
  import Dialectic.AccountsFixtures
  import Dialectic.McpFixtures
  alias Dialectic.Accounts.Graph
  alias Dialectic.DbActions.Graphs
  alias Dialectic.Integrations.{ChatGrids, Exploration, GridAction}
  alias Dialectic.Repo

  setup :configure_mcp

  setup %{conn: conn} do
    user = user_fixture()

    {:ok, grid} =
      ChatGrids.create(
        user,
        Map.put(grid_draft(), "title", "Visibility #{System.unique_integer([:positive])}")
      )

    api =
      put_req_header(
        conn,
        "authorization",
        "Bearer " <> issue_token(user, "grids:read grids:visibility")
      )

    %{user: user, grid: grid, api: api}
  end

  test "visibility is idempotent, revision guarded and independent of content", %{
    api: api,
    grid: grid,
    user: user
  } do
    path = ~p"/api/mcp/grids/#{grid.slug}/visibility"

    params = %{
      request_id: Ecto.UUID.generate(),
      visibility: "public",
      expected_revision: grid.data_revision
    }

    receipt = api |> post(path, params) |> json_response(200)
    assert receipt["result"]["visibility"] == "public"
    assert receipt["result"]["visibility_version"] == 1
    assert receipt["result"]["anonymous_access_verification"] == "pending"
    assert Repo.get!(Graph, grid.title).data_revision == grid.data_revision
    assert api |> post(path, params) |> json_response(200) == receipt

    assert api |> post(path, %{params | visibility: "private"}) |> json_response(409)

    stale = %{
      params
      | request_id: Ecto.UUID.generate(),
        expected_revision: grid.data_revision + 1
    }

    assert api |> post(path, stale) |> json_response(409) |> Map.fetch!("code") ==
             "stale_revision"

    private = %{request_id: Ecto.UUID.generate(), visibility: "private"}

    assert api
           |> post(path, private)
           |> json_response(200)
           |> get_in(["result", "visibility_version"]) == 2

    assert build_conn() |> get(~p"/api/public/grids/#{grid.slug}") |> json_response(404)
    assert build_conn() |> get(~p"/api/graphs/json/#{grid.slug}") |> json_response(403)

    assert {:ok, replay} =
             Dialectic.Integrations.GridActions.get_operation(user, params.request_id)

    assert replay.result["visibility"] == "public"
    refute Repo.get!(Graph, grid.title).is_public
  end

  test "create grants do not acquire visibility authority and access is rechecked", %{
    conn: conn,
    api: api,
    grid: grid,
    user: user
  } do
    path = ~p"/api/mcp/grids/#{grid.slug}/visibility"
    params = %{request_id: Ecto.UUID.generate(), visibility: "private"}

    old =
      put_req_header(
        conn,
        "authorization",
        "Bearer " <> issue_token(user, "grids:create grids:read")
      )

    assert old |> post(path, params) |> json_response(403)

    other =
      put_req_header(
        conn,
        "authorization",
        "Bearer " <> issue_token(user_fixture(), "grids:visibility")
      )

    assert other |> post(path, params) |> json_response(404)
    receipt = api |> post(path, params) |> json_response(200)

    Repo.get!(Graph, grid.title)
    |> Ecto.Changeset.change(user_id: user_fixture().id)
    |> Repo.update!()

    assert api |> post(path, params) |> json_response(404)
    assert api |> get(~p"/api/mcp/operations/#{receipt["request_id"]}") |> json_response(404)
  end

  test "UI and MCP cannot publish active exploration; private remains available", %{
    user: user,
    api: api,
    grid: grid
  } do
    Repo.insert!(%Exploration{
      user_id: user.id,
      request_id: Ecto.UUID.generate(),
      graph_title: grid.title
    })

    assert {:error, :generation_in_progress} = Graphs.set_graph_public(grid, user, true)

    params = %{
      request_id: Ecto.UUID.generate(),
      visibility: "public",
      expected_revision: grid.data_revision
    }

    assert api
           |> post(~p"/api/mcp/grids/#{grid.slug}/visibility", params)
           |> json_response(409)
           |> Map.fetch!("code") == "generation_in_progress"

    assert {:ok, _} = Graphs.set_graph_public(grid, user, false)
    assert Repo.aggregate(GridAction, :count) == 0
  end

  test "export preserves all node classes without generating or inventing brief fields", %{
    api: api,
    conn: conn,
    grid: grid
  } do
    path = ~p"/api/mcp/grids/#{grid.slug}/export"
    assert conn |> get(path, revision: grid.data_revision) |> json_response(401)
    before_count = Repo.aggregate(Oban.Job, :count)
    export = api |> get(path, revision: grid.data_revision) |> json_response(200)
    assert export["brief_status"] == "not_prepared"
    assert export["claims"] == nil
    assert export["final_content_hash"] == export["content_hash"]
    assert length(export["nodes"]) == 2
    assert length(export["edges"]) == 1
    assert Repo.aggregate(Oban.Job, :count) == before_count

    assert api
           |> get(path, revision: grid.data_revision, profile: "unknown")
           |> json_response(422)
  end

  test "a delayed verification cannot affirm an obsolete visibility intent", %{
    api: api,
    grid: grid
  } do
    uuid = Ecto.UUID.generate()

    api
    |> post(
      ~p"/api/mcp/grids/#{grid.slug}/visibility",
      %{request_id: uuid, visibility: "public", expected_revision: grid.data_revision}
    )
    |> json_response(200)

    api
    |> post(
      ~p"/api/mcp/grids/#{grid.slug}/visibility",
      %{request_id: Ecto.UUID.generate(), visibility: "private"}
    )
    |> json_response(200)

    assert :ok =
             Dialectic.Workers.VisibilityVerificationWorker.perform(%Oban.Job{
               args: %{"request_id" => uuid, "user_id" => grid.user_id}
             })

    receipt = Repo.get_by!(GridAction, request_id: uuid)
    assert receipt.verification["anonymous_access_verification"] == "failed"
    refute Repo.get!(Graph, grid.title).is_public
  end

  test "editorial cursors keep revision and preserve multi-parent edges", %{api: api, grid: grid} do
    nodes =
      for id <- 1..52,
          do: %{
            "id" => to_string(id),
            "content" => "Material #{id}",
            "class" => if(rem(id, 2) == 0, do: "question", else: "counterexample")
          }

    data = %{
      "nodes" => nodes,
      "edges" => [
        %{"data" => %{"source" => "1", "target" => "52"}},
        %{"data" => %{"source" => "2", "target" => "52"}}
      ]
    }

    grid |> Ecto.Changeset.change(data: data, data_revision: 1) |> Repo.update!()

    Repo.insert!(%Dialectic.Integrations.GridSnapshot{
      graph_title: grid.title,
      revision: 1,
      data: data
    })

    path = ~p"/api/mcp/grids/#{grid.slug}/export"

    operation =
      Repo.insert!(%GridAction{
        user_id: grid.user_id,
        graph_title: grid.title,
        request_id: Ecto.UUID.generate(),
        node_id: "52",
        parent_node_id: "1",
        action: "clarify",
        status: "queued"
      })

    first = api |> get(path, revision: 1) |> json_response(200)
    operation |> Ecto.Changeset.change(status: "failed") |> Repo.update!()
    assert length(first["nodes"]) == 50
    assert first["final_content_hash"] == nil

    Repo.get!(Graph, grid.title)
    |> Ecto.Changeset.change(data_revision: 2, data: grid.data)
    |> Repo.update!()

    second = api |> get(path, revision: 1, cursor: first["next_cursor"]) |> json_response(200)
    assert length(second["nodes"]) == 2
    assert second["content_hash"] == first["content_hash"]
    assert second["next_cursor"] == nil
    assert Enum.find(second["nodes"], &(&1["id"] == "52"))["parent_node_ids"] == ["1", "2"]
    assert api |> get(path, revision: 2, cursor: first["next_cursor"]) |> json_response(409)
  end

  test "publication rejects unsaved live edits and deferred saves until the reviewed revision is current",
       %{user: user, grid: grid} do
    alias Dialectic.Integrations.GridVisibility
    GraphManager.get_graph(grid.title)
    GraphManager.set_node_content(grid.title, "1", "A newer private edit")

    params = %{
      "request_id" => Ecto.UUID.generate(),
      "visibility" => "public",
      "expected_revision" => grid.data_revision
    }

    assert {:error, :stale} = GridVisibility.set(user, grid.slug, params)
    assert {:error, :stale} = Graphs.set_graph_public(grid, user, true)
    refute Repo.reload!(grid).is_public
    refute Repo.get_by(GridAction, request_id: params["request_id"])

    {:ok, job} = GraphManager.save_graph(grid.title)
    assert {:error, :stale} = GridVisibility.set(user, grid.slug, params)
    assert :ok = Dialectic.DbActions.DbWorker.perform(job)
    saved = Repo.reload!(grid)
    assert saved.data_revision > grid.data_revision
    assert {:error, :stale} = GridVisibility.set(user, grid.slug, params)
    params = %{params | "expected_revision" => saved.data_revision}
    assert {:ok, receipt} = GridVisibility.set(user, grid.slug, params)
    assert receipt.result_revision == saved.data_revision
  end

  test "inactive or pruned coordinators do not block publication", %{user: user, grid: grid} do
    alias Dialectic.Integrations.{Exploration, GridVisibility}

    for terminal <- ["cancelled", "discarded", "completed", "pruned"] do
      {:ok, _} = GridVisibility.change(grid, user, false)
      job = %{} |> Oban.Job.new(worker: Dialectic.Workers.ExplorationWorker) |> Repo.insert!()

      exploration =
        Repo.insert!(%Exploration{
          user_id: user.id,
          graph_title: grid.title,
          request_id: Ecto.UUID.generate(),
          coordinator_job_id: job.id,
          stage: "testing"
        })

      params = %{
        "request_id" => Ecto.UUID.generate(),
        "visibility" => "public",
        "expected_revision" => grid.data_revision
      }

      assert {:error, :generation_in_progress} = GridVisibility.set(user, grid.slug, params)

      if terminal == "pruned",
        do: Repo.delete!(job),
        else: job |> Ecto.Changeset.change(state: terminal) |> Repo.update!()

      assert {:ok, _} = GridVisibility.set(user, grid.slug, params)
      Repo.delete!(exploration)
    end
  end

  test "owned listing reports the persisted visibility version", %{api: api, grid: grid} do
    for _ <- 1..2 do
      api
      |> post(
        ~p"/api/mcp/grids/#{grid.slug}/visibility",
        %{request_id: Ecto.UUID.generate(), visibility: "private"}
      )
      |> json_response(200)
    end

    result = api |> get(~p"/api/mcp/grids") |> json_response(200)
    listed = Enum.find(result["grids"], &(&1["id"] == grid.slug))
    assert listed["visibility_version"] == 2
  end
end
