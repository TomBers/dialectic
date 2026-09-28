defmodule Dialectic.LearningFoldersTest do
  use Dialectic.DataCase, async: true

  import Dialectic.AccountsFixtures
  import Dialectic.LearningFixtures

  alias Dialectic.{Learning, Repo}
  alias Dialectic.Accounts.Graph
  alias Dialectic.Learning.Collection

  setup do
    user = user_fixture()
    {:ok, root} = Learning.create_collection(user, %{name: "Economics"})
    {:ok, child} = Learning.create_collection(user, %{name: "Macro"}, root.id)
    {:ok, leaf} = Learning.create_collection(user, %{name: "Inflation"}, child.id)
    %{user: user, root: root, child: child, leaf: leaf}
  end

  test "folders have complete paths and names are unique only among siblings", %{
    user: user,
    root: root,
    child: child,
    leaf: leaf
  } do
    rows = Map.new(Learning.list_collections(user), &{&1.id, &1})
    assert rows[leaf.id].path == "Economics / Macro / Inflation"
    assert rows[leaf.id].ancestor_ids == [root.id, child.id]
    assert rows[leaf.id].depth == 2

    assert {:error, duplicate} =
             Learning.create_collection(user, %{name: " inflation "}, child.id)

    assert errors_on(duplicate).name == ["has already been taken"]
    assert {:ok, _} = Learning.create_collection(user, %{name: "Inflation"}, root.id)
    assert {:ok, _} = Learning.create_collection(user, %{name: "Inflation"})

    assert {:ok, created} =
             Learning.create_collection(user, %{name: "Trusted parent", parent_id: leaf.id})

    assert created.parent_id == nil
  end

  test "moving a folder preserves its subtree and grid memberships", %{
    user: user,
    root: root,
    child: child,
    leaf: leaf
  } do
    grid = learning_grid_fixture(user)
    {:ok, _} = Learning.add_grid(user, leaf.id, grid.title)
    {:ok, destination} = Learning.create_collection(user, %{name: "Revision"})
    assert {:ok, moved} = Learning.move_collection(user, child.id, destination.id)
    assert moved.parent_id == destination.id
    assert Learning.list_grids(user, collection_id: root.id, include_subfolders: true) == []

    assert [row] =
             Learning.list_grids(user, collection_id: destination.id, include_subfolders: true)

    assert row.title == grid.title
    assert [%{path: "Revision / Macro / Inflation"}] = row.collections
    assert {:ok, moved} = Learning.move_collection(user, child.id, "root")
    assert moved.parent_id == nil
    assert Learning.get_collection(user, leaf.id).parent_id == child.id
  end

  test "self, descendant, foreign, and topic destinations cannot mutate the tree", %{
    user: user,
    root: root,
    child: child,
    leaf: leaf
  } do
    other = user_fixture()
    {:ok, foreign} = Learning.create_collection(other, %{name: "Other"})
    topic = Repo.insert!(%Collection{user_id: user.id, name: "Auto topic", origin: :tags})
    assert {:error, :cycle} = Learning.move_collection(user, root.id, root.id)
    assert {:error, :cycle} = Learning.move_collection(user, root.id, leaf.id)

    for destination <- [foreign.id, topic.id, "invalid"] do
      assert {:error, :invalid_parent} = Learning.move_collection(user, child.id, destination)

      assert {:error, :invalid_parent} =
               Learning.create_collection(user, %{name: "Invalid"}, destination)
    end

    assert {:error, :invalid_parent} = Learning.move_collection(other, root.id, foreign.id)
    assert {:error, :invalid_parent} = Learning.move_collection(user, topic.id, root.id)
    assert Learning.get_collection(user, root.id).parent_id == nil
    assert Learning.get_collection(user, child.id).parent_id == root.id
    assert Learning.list_grids(other, collection_id: root.id, include_subfolders: true) == []
  end

  test "a move that would duplicate a sibling name leaves the subtree intact", %{
    user: user,
    root: root,
    child: child,
    leaf: leaf
  } do
    {:ok, destination} = Learning.create_collection(user, %{name: "Revision"})
    {:ok, _} = Learning.create_collection(user, %{name: "macro"}, destination.id)
    assert {:error, changeset} = Learning.move_collection(user, child.id, destination.id)
    assert errors_on(changeset).name == ["has already been taken"]
    assert Learning.get_collection(user, child.id).parent_id == root.id
    assert Learning.get_collection(user, leaf.id).parent_id == child.id
  end

  test "including subfolders preserves saved filters, search, and access",
       %{user: user, root: root, child: child, leaf: leaf} do
    grid = learning_grid_fixture(user, %{title: "Inflation notes"})
    other = learning_grid_fixture(user, %{title: "Unemployment"})
    shared = learning_grid_fixture(user_fixture())
    for folder <- [root, child, leaf], do: Learning.add_grid(user, folder.id, grid.title)
    {:ok, _} = Learning.add_grid(user, leaf.id, other.title)
    {:ok, _} = Learning.add_grid(user, leaf.id, shared.title)
    {:ok, _} = Dialectic.DbActions.Notes.add_note(grid.title, "1", user)
    Repo.update!(Ecto.Changeset.change(shared, is_public: false))
    assert Learning.list_grids(user, collection_id: root.id) == []
    options = [collection_id: root.id, include_subfolders: true]
    assert length(Learning.list_grids(user, options)) == 2

    assert [%{title: "Inflation notes"}] =
             Learning.list_grids(user, options ++ [saved_kind: "bookmarks"])

    assert [%{title: "Unemployment"}] =
             Learning.list_grids(user, options ++ [search: "unemployment"])

    first = Learning.list_grids(user, options ++ [limit: 1])
    second = Learning.list_grids(user, options ++ [limit: 1, offset: 1])
    assert first != second
    assert Learning.list_grids(user, options ++ [offset: 2]) == []
  end

  test "deleting a folder removes descendants but keeps grids and other memberships", %{
    user: user,
    child: child,
    leaf: leaf
  } do
    grid = learning_grid_fixture(user, %{is_public: false})
    {:ok, other_collection} = Learning.create_collection(user, %{name: "Revision"})
    {:ok, _} = Learning.add_grid(user, other_collection.id, grid.title)
    {:ok, _} = Learning.add_grid(user, leaf.id, grid.title)
    assert {:ok, _} = Learning.delete_collection(user, child.id)
    assert Learning.get_collection(user, child.id) == nil
    assert Learning.get_collection(user, leaf.id) == nil
    assert Repo.get!(Graph, grid.title).is_deleted == false
    assert [row] = Learning.list_grids(user, collection_id: other_collection.id)
    assert row.title == grid.title
    assert Enum.map(row.collections, & &1.id) == [other_collection.id]
  end

  test "filing moves a grid within one collection while keeping other collections and topics", %{
    user: user,
    root: root,
    child: child,
    leaf: leaf
  } do
    grid = learning_grid_fixture(user)
    {:ok, revision} = Learning.create_collection(user, %{name: "Revision"})
    {:ok, sibling} = Learning.create_collection(user, %{name: "Micro"}, root.id)
    topic = Repo.insert!(%Collection{user_id: user.id, name: "Auto topic", origin: :tags})
    for place <- [revision, topic, root], do: Learning.add_grid(user, place.id, grid.title)

    for destination <- [leaf, sibling, child, root] do
      assert {:ok, _} = Learning.add_grid(user, destination.id, grid.title)
      assert {:ok, _} = Learning.add_grid(user, destination.id, grid.title)
      assert [row] = Learning.list_grids(user)

      assert MapSet.new(Enum.map(row.collections, & &1.id)) ==
               MapSet.new([revision.id, topic.id, destination.id])

      assert [%{title: title}] = Learning.list_grids(user, collection_id: destination.id)
      assert title == grid.title
      counts = Map.new(Learning.list_collections(user), &{&1.id, &1.grid_count})

      for place <- [root, child, leaf, sibling] do
        assert counts[place.id] == if(place.id == destination.id, do: 1, else: 0)
      end
    end
  end

  test "invalid filing cannot remove an existing location", %{user: user, leaf: leaf} do
    grid = learning_grid_fixture(user)
    {:ok, foreign} = Learning.create_collection(user_fixture(), %{name: "Foreign"})
    {:ok, _} = Learning.add_grid(user, leaf.id, grid.title)
    assert {:error, :not_found} = Learning.add_grid(user, foreign.id, grid.title)
    assert [row] = Learning.list_grids(user, collection_id: leaf.id)
    assert row.title == grid.title
  end

  test "moving a folder into another collection keeps each grid in the moved folder", %{
    user: user,
    child: child,
    leaf: leaf
  } do
    grid = learning_grid_fixture(user)
    {:ok, destination} = Learning.create_collection(user, %{name: "Revision"})
    {:ok, _} = Learning.add_grid(user, leaf.id, grid.title)
    {:ok, _} = Learning.add_grid(user, destination.id, grid.title)
    assert {:ok, _} = Learning.move_collection(user, child.id, destination.id)
    assert Learning.list_grids(user, collection_id: destination.id) == []

    assert [%{collections: [%{id: id}]}] =
             Learning.list_grids(user, collection_id: destination.id, include_subfolders: true)

    assert id == leaf.id
  end

  test "initializing topics preserves manual filing at every depth", %{
    user: user,
    root: root,
    child: child,
    leaf: leaf
  } do
    assert {:ok, :initialized} = Learning.initialize_topics(user)

    filed =
      for folder <- [root, child, leaf] do
        grid = learning_grid_fixture(user, %{tags: [" ECONOMICS "]})
        {:ok, _} = Learning.add_grid(user, folder.id, grid.title)
        {folder, grid}
      end

    assert {:ok, :initialized} = Learning.initialize_topics(user)
    assert {:ok, :already_initialized} = Learning.initialize_topics(user)

    for {folder, grid} <- filed do
      assert [row] = Learning.list_grids(user, collection_id: folder.id)
      assert row.title == grid.title
      assert Enum.map(row.collections, & &1.id) == [folder.id]
    end
  end

  test "topic initialization skips only grids already filed in the matching collection tree", %{
    user: user,
    root: root,
    leaf: leaf
  } do
    {:ok, revision} = Learning.create_collection(user, %{name: "Revision"})
    filed = learning_grid_fixture(user, %{tags: ["economics", "history"]})
    unfiled = learning_grid_fixture(user, %{tags: ["economics", "history"]})
    {:ok, _} = Learning.add_grid(user, leaf.id, filed.title)
    {:ok, _} = Learning.add_grid(user, revision.id, filed.title)
    {:ok, _} = Learning.add_grid(user, revision.id, unfiled.title)

    assert {:ok, :initialized} = Learning.initialize_topics(user)

    assert [root_row] = Learning.list_grids(user, collection_id: root.id)
    assert root_row.title == unfiled.title
    assert [leaf_row] = Learning.list_grids(user, collection_id: leaf.id)
    assert leaf_row.title == filed.title

    history = Enum.find(Learning.list_collections(user), &(&1.name == "History"))
    assert history.origin == :tags

    for collection <- [revision, history] do
      titles = Learning.list_grids(user, collection_id: collection.id) |> Enum.map(& &1.title)
      assert MapSet.new(titles) == MapSet.new([filed.title, unfiled.title])
    end
  end

  test "initializing topics does not turn a same-named nested folder into a topic", %{
    user: user,
    leaf: leaf
  } do
    learning_grid_fixture(user, %{tags: ["inflation"]})
    assert {:ok, :initialized} = Learning.initialize_topics(user)
    rows = Learning.list_collections(user)
    topic = Enum.find(rows, &(&1.origin == :tags))
    assert topic.name == "Inflation"
    assert topic.parent_id == nil
    assert topic.grid_count == 1
    assert Enum.find(rows, &(&1.id == leaf.id)).grid_count == 0
  end
end
