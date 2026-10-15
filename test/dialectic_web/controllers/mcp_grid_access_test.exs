defmodule DialecticWeb.McpGridAccessTest do
  use DialecticWeb.ConnCase, async: false

  import Dialectic.AccountsFixtures
  import Dialectic.McpFixtures

  alias Dialectic.DbActions.Sharing
  alias Dialectic.Integrations.ChatGrids
  alias Dialectic.Repo

  setup :configure_mcp

  test "one read endpoint uses application access for owners, invitees and public visitors", %{
    conn: conn
  } do
    owner = user_fixture()
    reader = user_fixture()
    {:ok, graph} = ChatGrids.create(owner, grid_draft())
    path = ~p"/api/mcp/grids/#{graph.slug}"
    owner_conn = authenticated(conn, owner)
    reader_conn = authenticated(conn, reader)

    assert conn |> get(path) |> json_response(401)
    assert conn |> log_in_user(owner) |> get(path) |> json_response(401)
    assert reader_conn |> get(path) |> json_response(404)
    owned = owner_conn |> get(path) |> json_response(200)
    assert owned["grid"]["visibility"] == "private"

    {:ok, _share} = Sharing.invite_user(graph, reader.email)
    shared_response = get(reader_conn, path)
    assert json_response(shared_response, 200) == owned
    assert get_resp_header(shared_response, "cache-control") == ["no-store"]
    refute Map.has_key?(owned["grid"], "share_token")

    listing = reader_conn |> get(~p"/api/mcp/grids") |> json_response(200)
    assert listing["grids"] == []

    assert Sharing.remove_invite(graph, reader.email, owner) == :ok
    assert reader_conn |> get(path) |> json_response(404)

    graph = graph |> Ecto.Changeset.change(is_public: true, is_published: false) |> Repo.update!()
    public = conn |> get(path) |> json_response(200)
    assert public["grid"]["visibility"] == "public"
    assert reader_conn |> get(path) |> json_response(200) == public
    assert conn |> get(~p"/api/public/grids/#{graph.slug}") |> json_response(404)

    graph |> Ecto.Changeset.change(is_deleted: true) |> Repo.update!()
    assert owner_conn |> get(path) |> json_response(404)
    assert reader_conn |> get(path) |> json_response(404)
    assert conn |> get(path) |> json_response(401)
  end

  test "contributions require OAuth scope, application access and an unlocked grid",
       %{
         conn: conn
       } do
    owner = user_fixture()
    visitor = user_fixture()
    {:ok, graph} = ChatGrids.create(owner, grid_draft())

    on_exit(fn ->
      case :global.whereis_name({:graph, graph.title}) do
        pid when is_pid(pid) -> DynamicSupervisor.terminate_child(GraphSupervisor, pid)
        _ -> :ok
      end
    end)

    graph |> Ecto.Changeset.change(is_public: true) |> Repo.update!()
    path = ~p"/api/mcp/grids/#{graph.slug}"

    for header <- ["Bearer invalid", "Basic invalid", ""] do
      assert conn |> put_req_header("authorization", header) |> get(path) |> json_response(401)
    end

    assert conn
           |> authenticated(owner, "grids:create")
           |> get(path)
           |> json_response(403)

    params = %{
      request_id: Ecto.UUID.generate(),
      parent_node_id: "1",
      content: "A public contribution"
    }

    nodes_path = ~p"/api/mcp/grids/#{graph.slug}/nodes"
    assert conn |> post(nodes_path, params) |> json_response(401)
    assert conn |> authenticated(visitor) |> post(nodes_path, params) |> json_response(403)

    result =
      conn
      |> authenticated(visitor, "grids:append")
      |> post(nodes_path, params)
      |> json_response(200)

    assert result["grid"]["visibility"] == "public"
    assert result["status"] == "completed"
    assert GraphManager.find_node_by_id(graph.title, result["node"]["id"]).user == visitor.email
    assert Repo.reload!(graph).user_id == owner.id

    operation_path = ~p"/api/mcp/operations/#{params.request_id}"
    assert conn |> authenticated(visitor) |> get(operation_path) |> json_response(200) == result
    assert conn |> authenticated(owner) |> get(operation_path) |> json_response(404)

    next_params = %{params | request_id: Ecto.UUID.generate()}
    graph |> Repo.reload!() |> Ecto.Changeset.change(is_locked: true) |> Repo.update!()

    assert conn
           |> authenticated(visitor, "grids:append")
           |> post(nodes_path, next_params)
           |> json_response(423)

    graph
    |> Repo.reload!()
    |> Ecto.Changeset.change(is_locked: false, is_public: false)
    |> Repo.update!()

    assert conn
           |> authenticated(visitor, "grids:append")
           |> post(nodes_path, next_params)
           |> json_response(404)

    assert conn |> authenticated(visitor) |> get(operation_path) |> json_response(404)

    {:ok, _share} = Sharing.invite_user(graph, visitor.email)

    shared =
      conn
      |> authenticated(visitor, "grids:append")
      |> post(nodes_path, next_params)
      |> json_response(200)

    assert shared["grid"]["visibility"] == "private"

    assert Repo.aggregate(Dialectic.Integrations.GridAction, :count) == 2
  end

  defp authenticated(conn, user, scope \\ "grids:read") do
    put_req_header(conn, "authorization", "Bearer " <> issue_token(user, scope))
  end
end
