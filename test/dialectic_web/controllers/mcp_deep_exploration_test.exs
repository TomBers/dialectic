defmodule DialecticWeb.McpDeepExplorationTest do
  use DialecticWeb.ConnCase, async: false
  import Dialectic.AccountsFixtures
  import Dialectic.McpFixtures
  alias Dialectic.Accounts.Graph
  alias Dialectic.Integrations.{ChatGrids, ContentReceipts, GridAction, GridContent}
  alias Dialectic.Repo

  @answer "Green roofs can reduce urban heat. Their cooling effect depends on local conditions."
  @plan """
  ## Learning plan: Urban heat
  ### Best next actions
  - **Clarify terms** — Define cooling before comparing policies.
  - **Test with a counterexample** — Examine where an intervention failed.
  - **Find related ideas** — Connect heat policy to public health.
  ### Paths to explore
  - **Cooling homes** — How can homes stay safe during heat waves? — Compares practical interventions.
  - **Public space** — Which street designs reduce dangerous heat? — Connects planning to exposure.
  - **Health systems** — How should clinics prepare for extreme heat? — Tests readiness.
  - **Energy demand** — Can cooling expand without overloading the grid? — Links adaptation to infrastructure.
  - **Unequal exposure** — Who faces the greatest heat risk and why? — Surfaces distributional consequences.
  """

  setup :configure_mcp

  setup %{conn: conn} do
    user = user_fixture()

    draft =
      grid_draft()
      |> Map.put("title", "Deep exploration #{System.unique_integer([:positive])}")
      |> Map.update!("nodes", fn [origin, answer] ->
        [origin, Map.put(answer, "content", @answer)]
      end)

    {:ok, grid} = ChatGrids.create(user, draft)

    api =
      put_req_header(
        conn,
        "authorization",
        "Bearer " <> issue_token(user, "grids:read grids:append")
      )

    on_exit(fn ->
      case :global.whereis_name({:graph, grid.title}) do
        pid when is_pid(pid) -> DynamicSupervisor.terminate_child(GraphSupervisor, pid)
        _ -> :ok
      end
    end)

    %{user: user, grid: grid, api: api}
  end

  test "focused reads expose complete node content and connections with fresh access checks", %{
    api: api,
    grid: grid,
    conn: conn,
    user: user
  } do
    path = ~p"/api/mcp/grids/#{grid.slug}/nodes/2"
    read = api |> get(path) |> json_response(200)
    assert read["node"]["content"] == @answer
    assert read["node"]["content_hash"] == GridContent.content_hash(@answer)
    assert [%{"id" => "1"}] = read["parents"]
    assert read["children"] == []
    assert read["snapshot_revision"] == grid.data_revision
    refute Jason.encode!(read) =~ user.email
    assert conn |> get(path) |> json_response(401)
    other = put_req_header(conn, "authorization", "Bearer " <> issue_token(user_fixture()))
    assert other |> get(path) |> json_response(404)

    GraphManager.set_node_content(grid.title, "2", "A live edit before its delayed save")
    live = api |> get(path) |> json_response(200)
    assert live["node"]["content"] == "A live edit before its delayed save"
    assert live["snapshot_revision"] == nil
    assert api |> get(path, revision: grid.data_revision) |> json_response(200) == read
    assert Repo.aggregate(Oban.Job, :count) == 0
    assert Repo.get!(Graph, grid.title).data_revision == grid.data_revision

    grid |> Ecto.Changeset.change(is_public: true, is_locked: true) |> Repo.update!()
    public = conn |> get(path) |> json_response(200)
    refute public["editing_enabled"]
    GraphManager.delete_node(grid.title, "2")
    assert api |> get(path) |> json_response(404)
  end

  test "thinking tools focus on an exact passage and retain its provenance across retry and restart",
       %{api: api, grid: grid} do
    params = %{
      request_id: Ecto.UUID.generate(),
      node_id: "2",
      action: "assumptions",
      selection: "Their cooling effect depends on local conditions.",
      expected_content_hash: GridContent.content_hash(@answer)
    }

    path = ~p"/api/mcp/grids/#{grid.slug}/actions"
    result = api |> post(path, params) |> json_response(200)
    assert result["node"]["class"] == "assumptions"

    assert result["node"]["source_reference"] == %{
             "node_id" => "2",
             "content_hash" => params.expected_content_hash,
             "text" => params.selection
           }

    operation = Repo.get_by!(GridAction, request_id: params.request_id)
    job = Repo.get!(Oban.Job, operation.job_id)
    assert job.args["instruction"] =~ params.selection
    assert job.args["instruction"] =~ "Green roofs"

    assert GraphManager.find_node_by_id(grid.title, result["node"]["id"]).source_text ==
             params.selection

    assert api |> post(path, params) |> json_response(200) == result

    assert api
           |> post(path, %{params | selection: "Green roofs"})
           |> json_response(409)
           |> Map.fetch!("code") == "request_conflict"

    DynamicSupervisor.terminate_child(GraphSupervisor, :global.whereis_name({:graph, grid.title}))

    read =
      api
      |> get(~p"/api/mcp/grids/#{grid.slug}/nodes/#{result["node"]["id"]}")
      |> json_response(200)

    assert read["node"]["source_reference"] == result["node"]["source_reference"]
    assert Repo.aggregate(GridAction, :count) == 1
    assert Repo.aggregate(Oban.Job, :count) == 1
  end

  test "bad or stale selections and pending source answers cannot enqueue new generation", %{
    api: api,
    grid: grid
  } do
    path = ~p"/api/mcp/grids/#{grid.slug}/actions"

    params = %{
      request_id: Ecto.UUID.generate(),
      node_id: "2",
      action: "explain",
      selection: "Green roofs",
      expected_content_hash: GridContent.content_hash(@answer)
    }

    assert api |> post(path, Map.delete(params, :expected_content_hash)) |> json_response(422)

    assert api
           |> post(path, %{params | selection: "An invented passage"})
           |> json_response(422)
           |> Map.fetch!("code") == "invalid_selection"

    GraphManager.set_node_content(grid.title, "2", "Changed by a user")
    stale = api |> post(path, params) |> json_response(409)
    assert stale["code"] == "source_changed"
    assert stale["request_id"] == params.request_id
    refute stale["request_accepted"]
    assert Repo.aggregate(Oban.Job, :count) == 0
    assert Repo.aggregate(GridAction, :count) == 0
    GraphManager.set_node_content(grid.title, "2", @answer)
    first = api |> post(path, params) |> json_response(200)
    GraphManager.set_node_content(grid.title, first["node"]["id"], "Streaming partial text")

    pending =
      api
      |> post(path, %{
        request_id: Ecto.UUID.generate(),
        node_id: first["node"]["id"],
        action: "related_ideas"
      })
      |> json_response(409)

    assert pending["code"] == "generation_in_progress"
    assert pending["retryable"]
    assert Repo.aggregate(Oban.Job, :count) == 1
  end

  test "learning plans use the native contract and their paths can grow a grid", %{
    api: api,
    grid: grid
  } do
    params = %{
      request_id: Ecto.UUID.generate(),
      node_id: "2",
      action: "learning_plan",
      expected_content_hash: GridContent.content_hash(@answer)
    }

    result = api |> post(~p"/api/mcp/grids/#{grid.slug}/actions", params) |> json_response(200)
    assert result["node"]["class"] == "learning_plan"
    operation = Repo.get_by!(GridAction, request_id: params.request_id)
    job = Repo.get!(Oban.Job, operation.job_id)
    assert job.args["response_contract"] == "guided_learning_plan"
    assert job.args["guided_target"]["node_id"] == "2"

    assert {:accept, plan} =
             Dialectic.Workers.LLMWorker.guided_learning_plan_response_action(job.args, @plan)

    {:ok, text} = Dialectic.Responses.GuidedLearningPlan.render(plan)

    GraphManager.update_vertex_fields(grid.title, operation.node_id, %{
      guided_plan: plan,
      content: text
    })

    assert {:ok, revision} =
             ContentReceipts.persist_generation(grid.title, operation.node_id, job.id)

    job |> Ecto.Changeset.change(state: "completed") |> Repo.update!()

    read =
      api |> get(~p"/api/mcp/grids/#{grid.slug}/nodes/#{operation.node_id}") |> json_response(200)

    assert length(read["node"]["learning_plan"]["actions"]) == 3
    assert length(read["node"]["learning_plan"]["paths"]) == 5

    assert hd(read["node"]["learning_plan"]["actions"])["target"]["source_hash"] ==
             params.expected_content_hash

    status = api |> get(~p"/api/mcp/operations/#{params.request_id}") |> json_response(200)
    assert status["snapshot_revision"] == revision
    assert status["node"]["learning_plan"] == read["node"]["learning_plan"]
    path = hd(read["node"]["learning_plan"]["paths"])

    question = %{
      request_id: Ecto.UUID.generate(),
      parent_node_id: operation.node_id,
      kind: "question",
      content: path["question"],
      expected_content_hash: read["node"]["content_hash"]
    }

    branch = api |> post(~p"/api/mcp/grids/#{grid.slug}/nodes", question) |> json_response(200)
    assert branch["node"]["content"] == path["question"]
    assert branch["node"]["parent_node_id"] == operation.node_id
    assert branch["answer_node"]["parent_node_id"] == branch["node"]["id"]
    follow_up = Repo.get_by!(GridAction, request_id: question.request_id)
    assert Repo.get!(Oban.Job, follow_up.job_id).args["instruction"] =~ @answer
    GraphManager.set_node_content(grid.title, "2", "Changed since the plan was generated")

    assert api
           |> post(~p"/api/mcp/grids/#{grid.slug}/nodes", %{
             question
             | request_id: Ecto.UUID.generate()
           })
           |> json_response(409)
           |> Map.fetch!("code") == "source_changed"
  end

  test "custom questions on passages preserve wording and use the focused-question prompt", %{
    api: api,
    grid: grid
  } do
    params = %{
      request_id: Ecto.UUID.generate(),
      parent_node_id: "2",
      kind: "question",
      content: "What conditions matter most?",
      selection: "local conditions",
      expected_content_hash: GridContent.content_hash(@answer)
    }

    result = api |> post(~p"/api/mcp/grids/#{grid.slug}/nodes", params) |> json_response(200)
    assert result["node"]["content"] == params.content
    assert result["node"]["source_reference"]["text"] == params.selection
    operation = Repo.get_by!(GridAction, request_id: params.request_id)
    instruction = Repo.get!(Oban.Job, operation.job_id).args["instruction"]
    assert instruction =~ params.content
    assert instruction =~ params.selection
    assert instruction =~ @answer
  end

  test "selected learning plans bind their recommendations to the quoted passage", %{
    api: api,
    grid: grid
  } do
    params = %{
      request_id: Ecto.UUID.generate(),
      node_id: "2",
      action: "learning_plan",
      selection: "local conditions",
      expected_content_hash: GridContent.content_hash(@answer)
    }

    result = api |> post(~p"/api/mcp/grids/#{grid.slug}/actions", params) |> json_response(200)
    operation = Repo.get_by!(GridAction, request_id: params.request_id)
    job = Repo.get!(Oban.Job, operation.job_id)
    assert job.args["guided_target"]["content"] == params.selection
    assert job.args["guided_target"]["source_hash"] == params.expected_content_hash
    assert result["node"]["source_reference"]["text"] == params.selection

    assert {:accept, plan} =
             Dialectic.Workers.LLMWorker.guided_learning_plan_response_action(job.args, @plan)

    assert Enum.all?(plan.actions, &(&1.target.content == params.selection))
  end

  test "explanations, related ideas and both sides of a claim use their native prompts", %{
    api: api,
    grid: grid
  } do
    for {action, class} <- [
          {"explain", "explain"},
          {"related_ideas", "ideas"},
          {"thesis", "thesis"},
          {"antithesis", "antithesis"}
        ] do
      params = %{
        request_id: Ecto.UUID.generate(),
        node_id: "2",
        action: action,
        selection: "Green roofs can reduce urban heat.",
        expected_content_hash: GridContent.content_hash(@answer)
      }

      result = api |> post(~p"/api/mcp/grids/#{grid.slug}/actions", params) |> json_response(200)
      assert result["node"]["class"] == class
      operation = Repo.get_by!(GridAction, request_id: params.request_id)
      assert Repo.get!(Oban.Job, operation.job_id).args["instruction"] =~ params.selection
    end
  end

  test "synthesis connects chosen branches and validates every source before writing", %{
    api: api,
    grid: grid
  } do
    nodes_path = ~p"/api/mcp/grids/#{grid.slug}/nodes"

    branches =
      for text <- ["Trees provide shade", "Heat risk varies across neighbourhoods"] do
        result =
          api
          |> post(nodes_path, %{
            request_id: Ecto.UUID.generate(),
            parent_node_id: "2",
            content: text
          })
          |> json_response(200)

        result["node"]["id"]
      end

    params = %{
      request_id: Ecto.UUID.generate(),
      node_id: List.last(branches),
      action: "synthesis",
      context_node_ids: ["2", hd(branches)]
    }

    path = ~p"/api/mcp/grids/#{grid.slug}/actions"
    result = api |> post(path, params) |> json_response(200)
    assert result["node"]["class"] == "synthesis"
    assert result["node"]["parent_node_ids"] == ["2" | branches]
    operation = Repo.get_by!(GridAction, request_id: params.request_id)
    {_, live_graph} = GraphManager.get_graph(grid.title)

    assert MapSet.new(:digraph.in_neighbours(live_graph, operation.node_id)) ==
             MapSet.new(["2" | branches])

    instruction = Repo.get!(Oban.Job, operation.job_id).args["instruction"]

    for text <- [@answer, "Trees provide shade", "Heat risk varies across neighbourhoods"],
        do: assert(instruction =~ text)

    for ids <- [[], [params.node_id], ["missing"], [hd(branches), hd(branches)]] do
      assert api
             |> post(path, %{params | request_id: Ecto.UUID.generate(), context_node_ids: ids})
             |> json_response(422)
    end

    assert Repo.aggregate(Oban.Job, :count) == 1
  end

  test "new actions enforce append scope and locks, while tool discovery is public", %{
    api: api,
    grid: grid,
    conn: conn,
    user: user
  } do
    tools =
      conn |> get(~p"/api/mcp/exploration-tools") |> json_response(200) |> Map.fetch!("tools")

    assert Enum.any?(
             tools,
             &(&1["action"] == "learning_plan" and &1["tool"] == "create_learning_plan")
           )

    assert Enum.any?(tools, &(&1["action"] == "synthesis" and not &1["selection_supported"]))

    read_only =
      put_req_header(conn, "authorization", "Bearer " <> issue_token(user, "grids:read"))

    path = ~p"/api/mcp/grids/#{grid.slug}/actions"
    params = %{request_id: Ecto.UUID.generate(), node_id: "2", action: "learning_plan"}
    assert read_only |> post(path, params) |> json_response(403)
    grid |> Ecto.Changeset.change(is_locked: true) |> Repo.update!()
    assert api |> post(path, params) |> json_response(423)
    assert Repo.aggregate(Oban.Job, :count) == 0
  end
end
