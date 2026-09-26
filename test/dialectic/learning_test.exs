defmodule Dialectic.LearningTest do
  use Dialectic.DataCase, async: true

  import Dialectic.AccountsFixtures
  import Dialectic.LearningFixtures

  alias Dialectic.{Learning, Repo}
  alias Dialectic.Accounts.Graph
  alias Dialectic.DbActions.{Notes, Sharing}

  setup do
    %{user: user_fixture(), other: user_fixture()}
  end

  test "starter topics reuse existing collections, normalize tags, and only initialize once", %{
    user: user,
    other: other
  } do
    grid = learning_grid_fixture(user, %{tags: [" Economics ", "ECONOMICS", "economic-history"]})
    saved = learning_grid_fixture(other, %{tags: ["economics"]})
    hidden = learning_grid_fixture(other, %{is_public: false, tags: ["secret"]})
    {:ok, _} = Notes.add_note(saved.title, "1", user)
    {:ok, _} = Notes.add_note(hidden.title, "1", user)
    {:ok, collection} = Learning.create_collection(user, %{name: "Economics"})
    assert {:ok, :initialized} = Learning.initialize_topics(user)
    topics = Learning.list_collections(user)
    assert Enum.map(topics, & &1.name) == ["Economic History", "Economics"]
    assert Enum.find(topics, &(&1.id == collection.id)).grid_count == 2
    assert Enum.find(topics, &(&1.id == collection.id)).origin == :manual
    assert Enum.find(topics, &(&1.name == "Economic History")).origin == :tags
    :ok = Learning.remove_grid(user, collection.id, grid.title)
    {:ok, _} = Learning.update_collection(user, collection.id, %{name: "My economics"})
    {:ok, _} = Learning.delete_collection(user, hd(topics).id)
    assert {:ok, :already_initialized} = Learning.initialize_topics(user)

    assert [%{name: "My economics", grid_count: 1, origin: :manual}] =
             Learning.list_collections(user)
  end

  test "an empty workspace can be organized once tagged grids arrive", %{user: user} do
    assert {:ok, :initialized} = Learning.initialize_topics(user)
    assert Learning.list_collections(user) == []
    learning_grid_fixture(user, %{tags: ["history"]})
    assert {:ok, :initialized} = Learning.initialize_topics(user)
    assert [%{name: "History", grid_count: 1, origin: :tags}] = Learning.list_collections(user)
  end

  test "a generated collection keeps its origin after editing and changing its grids", %{
    user: user
  } do
    grid = learning_grid_fixture(user, %{tags: ["history"]})
    assert {:ok, :initialized} = Learning.initialize_topics(user)
    [topic] = Learning.list_collections(user)

    assert {:ok, edited} =
             Learning.update_collection(user, topic.id, %{
               name: "My reading",
               description: "A personal selection",
               origin: :manual
             })

    assert edited.origin == :tags
    assert :ok = Learning.remove_grid(user, topic.id, grid.title)
    assert {:ok, :already_initialized} = Learning.initialize_topics(user)
    assert [%{name: "My reading", origin: :tags, grid_count: 0}] = Learning.list_collections(user)
    assert Learning.get_collection(user, topic.id).origin == :tags
  end

  test "saved content is scoped to the viewer and disappears when access is revoked", %{
    user: user,
    other: other
  } do
    grid = learning_grid_fixture(other)
    {:ok, own_note} = Notes.add_note(grid.title, "1", user)
    {:ok, other_note} = Notes.add_note(grid.title, "1", other)

    highlight =
      Repo.insert!(%Dialectic.Highlights.Highlight{
        mudg_id: grid.title,
        node_id: "1",
        text_source_type: "node",
        selection_start: 0,
        selection_end: 2,
        selected_text_snapshot: "Private annotation",
        created_by_user_id: other.id
      })

    assert [row] = Learning.list_grids(user, saved_kind: "bookmarks")
    assert Enum.map(row.bookmarks, & &1.id) == [own_note.id]
    assert row.highlights == []
    assert {:error, :not_found} = Learning.remove_bookmark(user, other_note.id)
    assert {:error, :not_found} = Learning.remove_highlight(user, highlight.id)
    Repo.update!(Ecto.Changeset.change(grid, is_public: false))
    assert Learning.list_grids(user, saved_kind: "bookmarks") == []
    assert Repo.get!(Dialectic.Accounts.Note, own_note.id).is_noted
  end

  test "collections are named, validated, and owned by the authenticated user", %{
    user: user,
    other: other
  } do
    assert {:ok, collection} =
             Learning.create_collection(user, %{
               name: " Economics ",
               user_id: other.id,
               origin: :tags
             })

    assert collection.name == "Economics"
    assert collection.user_id == user.id
    assert collection.origin == :manual
    assert {:error, duplicate} = Learning.create_collection(user, %{name: "economics"})
    assert errors_on(duplicate).name == ["has already been taken"]
    assert {:error, blank} = Learning.create_collection(user, %{name: "   "})
    assert errors_on(blank).name == ["can't be blank"]
    assert {:ok, _} = Learning.create_collection(other, %{name: "Economics"})
    assert is_nil(Learning.get_collection(other, collection.id))
    assert is_nil(Learning.get_collection(user, "invalid"))

    assert {:error, :not_found} =
             Learning.update_collection(other, collection.id, %{name: "Stolen"})

    assert {:error, :not_found} = Learning.delete_collection(other, collection.id)
  end

  test "grids can belong to multiple collections and survive removal and collection deletion", %{
    user: user
  } do
    grid = learning_grid_fixture(user)
    {:ok, economics} = Learning.create_collection(user, %{name: "Economics"})
    {:ok, revision} = Learning.create_collection(user, %{name: "Revision"})
    assert {:ok, _} = Learning.add_grid(user, economics.id, grid.title)
    assert {:ok, _} = Learning.add_grid(user, economics.id, grid.title)
    assert {:ok, _} = Learning.add_grid(user, revision.id, grid.title)
    assert [%{grid_count: 1}, %{grid_count: 1}] = Learning.list_collections(user)
    assert :ok = Learning.remove_grid(user, economics.id, grid.title)
    assert Learning.list_grids(user, collection_id: economics.id) == []
    assert [%{title: title}] = Learning.list_grids(user, collection_id: revision.id)
    assert title == grid.title

    assert {:ok, renamed} =
             Learning.update_collection(user, revision.id, %{
               name: "Exam prep",
               description: "Key questions"
             })

    assert renamed.name == "Exam prep"
    assert {:ok, _} = Learning.delete_collection(user, revision.id)
    assert Repo.get!(Graph, grid.title).is_deleted == false
    assert [%{title: ^title}] = Learning.list_grids(user)
  end

  test "collection membership never grants access to another user's private grids", %{
    user: user,
    other: other
  } do
    grid = learning_grid_fixture(other, %{is_public: false})
    {:ok, mine} = Learning.create_collection(user, %{name: "Mine"})
    {:ok, theirs} = Learning.create_collection(other, %{name: "Theirs"})
    assert {:error, :not_found} = Learning.add_grid(user, mine.id, grid.title)
    assert {:error, :not_found} = Learning.add_grid(user, theirs.id, grid.title)
    assert {:error, :not_found} = Learning.remove_grid(user, theirs.id, grid.title)
    assert {:ok, _} = Learning.add_grid(other, theirs.id, grid.title)
    assert Learning.list_grids(user, collection_id: theirs.id) == []
    assert {:ok, _} = Sharing.invite_user(grid, user.email)
    assert {:ok, _} = Learning.add_grid(user, mine.id, grid.title)
    assert [%{grid_count: 1}] = Learning.list_collections(user)
    assert :ok = Sharing.remove_invite(grid, user.email, other)
    assert Learning.list_grids(user) == []
    assert Learning.list_grids(user, collection_id: mine.id) == []
    assert [%{grid_count: 0}] = Learning.list_collections(user)
  end

  test "deleted grids and formerly public grids are excluded", %{user: user, other: other} do
    grid = learning_grid_fixture(other)
    {:ok, collection} = Learning.create_collection(user, %{name: "Reading"})
    {:ok, _} = Learning.add_grid(user, collection.id, grid.title)
    {:ok, _} = Notes.add_note(grid.title, "1", user)
    Repo.update!(Ecto.Changeset.change(grid, is_public: false))
    assert Learning.list_grids(user) == []
    Repo.update!(Ecto.Changeset.change(grid, is_deleted: true))
    assert Learning.list_grids(user) == []
    assert [%{grid_count: 0}] = Learning.list_collections(user)
    assert {:error, :not_found} = Learning.add_grid(user, collection.id, grid.title)
  end

  test "the library includes saved and followed grids without leaking unrelated public grids", %{
    user: user,
    other: other
  } do
    own = learning_grid_fixture(user, %{is_public: false})
    saved = learning_grid_fixture(other)
    followed = learning_grid_fixture(other)
    _unrelated = learning_grid_fixture(other)
    {:ok, _} = Notes.add_note(saved.title, "1", user)
    {:ok, _} = Dialectic.Follows.follow_graph(user, followed)

    assert MapSet.new(Enum.map(Learning.list_grids(user), & &1.title)) ==
             MapSet.new([own.title, saved.title, followed.title])
  end

  test "search matches titles and tags literally, with collection filtering and pagination", %{
    user: user
  } do
    economics = learning_grid_fixture(user, %{title: "Inflation 10%", tags: ["economics"]})
    history = learning_grid_fixture(user, %{title: "History notes"})
    {:ok, collection} = Learning.create_collection(user, %{name: "Economics"})
    {:ok, _} = Learning.add_grid(user, collection.id, economics.title)
    assert [%{title: "Inflation 10%"}] = Learning.list_grids(user, search: "ECONOMICS")
    assert [%{title: "Inflation 10%"}] = Learning.list_grids(user, search: "%")
    assert Learning.list_grids(user, collection_id: collection.id, search: "history") == []

    assert [%{title: "History notes"}] =
             Learning.list_grids(user, exclude_collection_id: collection.id)

    assert length(Learning.list_grids(user, limit: 1)) == 1
    assert length(Learning.list_grids(user, limit: 1, offset: 1)) == 1
    assert Learning.list_grids(user, offset: 2) == []
    assert Repo.get!(Graph, history.title)
  end
end
