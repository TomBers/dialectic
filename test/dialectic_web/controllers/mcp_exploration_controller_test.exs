defmodule DialecticWeb.McpExplorationControllerTest do
  use DialecticWeb.ConnCase, async: false

  import Dialectic.AccountsFixtures
  import Dialectic.McpFixtures

  alias Dialectic.Accounts.Graph
  alias Dialectic.Integrations.ChatGrids
  alias Dialectic.Repo

  setup :configure_mcp

  test "native creation and read-only progress have separate scopes", %{conn: conn} do
    user = user_fixture()
    params = %{"request_id" => Ecto.UUID.generate(), "question" => "What is a good explanation?"}

    create_conn =
      put_req_header(conn, "authorization", "Bearer " <> issue_token(user, "grids:create"))

    read_conn =
      put_req_header(conn, "authorization", "Bearer " <> issue_token(user, "grids:read"))

    assert conn |> post(~p"/api/mcp/explorations", params) |> json_response(401)
    assert read_conn |> post(~p"/api/mcp/explorations", params) |> json_response(403)
    created = create_conn |> post(~p"/api/mcp/explorations", params) |> json_response(200)
    title = created["grid"]["title"]
    on_exit(fn -> stop_graph(title) end)
    assert created["grid"]["visibility"] == "private"
    assert created["status"] == "queued"
    assert created["node"]["parent_node_id"] == nil
    assert created["answer_node"]["parent_node_id"] == created["node"]["id"]
    refute Map.has_key?(created["grid"], "share_token")

    request_id = params["request_id"]
    assert create_conn |> get(~p"/api/mcp/operations/#{request_id}") |> json_response(403)
    response = get(read_conn, ~p"/api/mcp/operations/#{request_id}")
    assert json_response(response, 200) == created
    assert get_resp_header(response, "cache-control") == ["no-store"]

    other_conn =
      put_req_header(
        conn,
        "authorization",
        "Bearer " <> issue_token(user_fixture(), "grids:read")
      )

    assert other_conn |> get(~p"/api/mcp/operations/#{request_id}") |> json_response(404)
    assert read_conn |> get(~p"/api/mcp/operations/invalid") |> json_response(404)
    assert Repo.aggregate(Oban.Job, :count) == 1

    repeated = create_conn |> post(~p"/api/mcp/explorations", params) |> json_response(200)
    assert repeated == created

    assert create_conn
           |> post(~p"/api/mcp/explorations", %{params | "question" => "Another question?"})
           |> json_response(409)

    assert create_conn
           |> post(~p"/api/mcp/explorations", %{"question" => ""})
           |> json_response(422)

    assert Repo.aggregate(Graph, :count) == 1
  end

  test "owned discovery is paginated, searchable and excludes other accounts and deleted grids",
       %{conn: conn} do
    user = user_fixture()

    owned =
      for title <- ["A 100% model", "B 1000 model", "C public model"] do
        {:ok, graph} = ChatGrids.create(user, Map.put(grid_draft(), "title", title))
        graph
      end

    public_graph = List.last(owned)
    public_graph |> Ecto.Changeset.change(is_public: true) |> Repo.update!()
    {:ok, removed} = ChatGrids.create(user, Map.put(grid_draft(), "title", "Removed model"))
    removed |> Ecto.Changeset.change(is_deleted: true) |> Repo.update!()

    {:ok, _other} =
      ChatGrids.create(user_fixture(), Map.put(grid_draft(), "title", "Other model"))

    assert conn |> get(~p"/api/mcp/grids") |> json_response(401)

    create_conn =
      put_req_header(conn, "authorization", "Bearer " <> issue_token(user, "grids:create"))

    assert create_conn |> get(~p"/api/mcp/grids") |> json_response(403)

    read_conn =
      put_req_header(conn, "authorization", "Bearer " <> issue_token(user, "grids:read"))

    first = read_conn |> get(~p"/api/mcp/grids", %{limit: "2"}) |> json_response(200)

    second =
      read_conn
      |> get(~p"/api/mcp/grids", %{limit: "2", cursor: first["next_cursor"]})
      |> json_response(200)

    assert second["next_cursor"] == nil
    results = first["grids"] ++ second["grids"]
    assert Enum.map(results, & &1["id"]) == owned |> Enum.map(& &1.slug) |> Enum.sort()
    assert Enum.find(results, &(&1["id"] == public_graph.slug))["visibility"] == "public"
    assert Enum.all?(results, &(Map.keys(&1) |> Enum.sort() == ~w(id tags title url visibility)))

    filtered = read_conn |> get(~p"/api/mcp/grids", %{query: "100%"}) |> json_response(200)
    assert [%{"title" => "A 100% model"}] = filtered["grids"]

    assert read_conn |> get(~p"/api/mcp/grids", %{query: "not found"}) |> json_response(200) == %{
             "grids" => [],
             "next_cursor" => nil
           }

    for params <- [
          %{limit: "0"},
          %{limit: "51"},
          %{limit: "1bad"},
          %{query: ["bad"]},
          %{query: String.duplicate("x", 101)},
          %{cursor: ["bad"]},
          %{cursor: ""},
          %{cursor: String.duplicate("x", 256)}
        ] do
      assert read_conn |> get(~p"/api/mcp/grids", params) |> json_response(400)
    end
  end

  defp stop_graph(title) do
    case :global.whereis_name({:graph, title}) do
      pid when is_pid(pid) -> DynamicSupervisor.terminate_child(GraphSupervisor, pid)
      _ -> :ok
    end
  end
end
