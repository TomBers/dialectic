defmodule Dialectic.Integrations.ChatGridsTest do
  use Dialectic.DataCase, async: true

  import Dialectic.AccountsFixtures
  import Dialectic.McpFixtures
  alias Dialectic.Accounts.Graph
  alias Dialectic.Integrations.{ChatGrids, GridRequest}

  test "saves a private owned grid, ignores forged ownership, and survives identical retries" do
    user = user_fixture()
    other_user = user_fixture()
    draft = Map.merge(grid_draft(), %{"user_id" => other_user.id, "is_public" => true})
    assert {:ok, graph} = ChatGrids.create(user, draft)
    assert graph.user_id == user.id
    refute graph.is_public
    assert graph.is_published
    assert [%{"id" => "1", "class" => "origin"}, %{"id" => "2"}] = graph.data["nodes"]
    assert [%{"data" => %{"source" => "1", "target" => "2"}}] = graph.data["edges"]
    assert ChatGrids.get(other_user, graph.slug) == nil
    assert {:ok, retry} = ChatGrids.create(user, draft)
    assert retry.title == graph.title
    assert Repo.aggregate(Graph, :count) == 1
    assert Repo.aggregate(GridRequest, :count) == 1
    assert {:error, :request_conflict} = ChatGrids.create(user, %{draft | "title" => "Different"})
  end

  test "new saves never overwrite a same-title grid and request ids are scoped to their owner" do
    user = user_fixture()
    draft = grid_draft()
    assert {:ok, first} = ChatGrids.create(user, draft)
    assert {:ok, second} = ChatGrids.create(user, %{draft | "request_id" => Ecto.UUID.generate()})
    assert first.title != second.title
    other_user = user_fixture()
    assert {:ok, third} = ChatGrids.create(other_user, draft)
    assert third.user_id == other_user.id
    assert third.title != first.title
    assert Repo.aggregate(Graph, :count) == 3
  end

  test "retries do not recreate soft-deleted or physically deleted grids" do
    user = user_fixture()
    draft = grid_draft()
    {:ok, graph} = ChatGrids.create(user, draft)
    graph |> Ecto.Changeset.change(is_deleted: true) |> Repo.update!()
    assert {:error, :unavailable} = ChatGrids.create(user, draft)
    Repo.delete!(graph)
    assert {:error, :unavailable} = ChatGrids.create(user, draft)
    assert Repo.aggregate(Graph, :count) == 0
  end

  test "rejects malformed, disconnected, cyclic, oversized, and dangling graphs atomically" do
    user = user_fixture()
    draft = grid_draft()
    [root, idea] = draft["nodes"]

    invalid_drafts = [
      %{draft | "request_id" => "invalid"},
      %{draft | "title" => " "},
      %{draft | "nodes" => []},
      %{draft | "nodes" => [root, root]},
      %{draft | "nodes" => [idea]},
      %{draft | "nodes" => [root, %{idea | "kind" => "origin"}]},
      %{draft | "nodes" => [root, %{idea | "kind" => "made_up"}]},
      %{draft | "nodes" => [root, %{idea | "content" => String.duplicate("x", 4001)}]},
      %{draft | "edges" => []},
      %{draft | "edges" => [%{"from" => "question", "to" => "missing"}]},
      %{draft | "edges" => draft["edges"] ++ [%{"from" => "idea", "to" => "question"}]},
      %{draft | "edges" => draft["edges"] ++ draft["edges"]},
      %{draft | "tags" => false}
    ]

    for invalid <- invalid_drafts, do: assert({:error, _} = ChatGrids.create(user, invalid))

    nodes = [
      root
      | Enum.map(
          1..20,
          &%{"id" => "node-#{&1}", "content" => String.duplicate("x", 4000), "kind" => "answer"}
        )
    ]

    assert {:error, _} = ChatGrids.create(user, %{draft | "nodes" => nodes})
    assert Repo.aggregate(Graph, :count) == 0
    assert Repo.aggregate(GridRequest, :count) == 0
  end
end
