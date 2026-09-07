defmodule Dialectic.DbActions.GraphCreationTransactionTest do
  use ExUnit.Case, async: false

  import Ecto.Query

  alias Dialectic.Accounts.Graph
  alias Dialectic.DbActions.Graphs
  alias Dialectic.Repo

  test "creates graphs and recovers from title collisions without a surrounding transaction" do
    title = "transaction-check-#{System.unique_integer([:positive])}"

    Ecto.Adapters.SQL.Sandbox.unboxed_run(Repo, fn ->
      try do
        refute Repo.in_transaction?()
        assert {:ok, original} = Graphs.create_new_graph(title)
        assert {:error, %Ecto.Changeset{}} = Graphs.create_new_graph(title)
        assert {:ok, separate} = Graphs.create_unique_graph(title, nil, "high_school")

        assert separate.title != original.title
        assert separate.slug != original.slug
        assert Repo.get!(Graph, original.title).title == title
        assert Repo.get!(Graph, separate.title).title == separate.title
        refute Repo.in_transaction?()
      after
        Repo.delete_all(
          from g in Graph, where: g.title == ^title or like(g.title, ^"#{title} (%")
        )
      end
    end)
  end
end
