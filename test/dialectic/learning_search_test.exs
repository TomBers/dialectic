defmodule Dialectic.LearningSearchTest do
  use Dialectic.DataCase, async: true

  import Dialectic.AccountsFixtures
  import Dialectic.LearningFixtures

  alias Dialectic.{Learning, Repo}
  alias Dialectic.DbActions.Sharing
  alias Dialectic.Highlights.Highlight

  test "finds private answer and source passages and excludes deleted nodes" do
    user = user_fixture()
    grid = learning_grid_fixture(user, %{is_public: false, data: data()})

    assert [%{title: title, search_matches: [%{node_id: "2", label: "Answer"}]}] =
             Learning.list_grids(user, search: "remembered phrase")

    assert title == grid.title

    assert [%{search_matches: [%{node_id: "3", label: "Source"}]}] =
             Learning.list_grids(user, search: "original evidence")

    assert Learning.list_grids(user, search: "removed passage") == []
    assert Dialectic.Search.search_public("remembered phrase") == []
  end

  test "search stays within the library, collection, saved filter and current access" do
    user = user_fixture()
    owner = user_fixture()
    grid = learning_grid_fixture(owner, %{is_public: false, data: data()})
    learning_grid_fixture(owner, %{data: data()})
    assert Learning.list_grids(user, search: "remembered phrase") == []
    {:ok, _} = Sharing.invite_user(grid, user.email)
    assert [%{title: title}] = Learning.list_grids(user, search: "remembered phrase")
    assert title == grid.title
    {:ok, collection} = Learning.create_collection(user, %{name: "Reading"})

    assert Learning.list_grids(user, search: "remembered phrase", collection_id: collection.id) ==
             []

    {:ok, _} = Learning.add_grid(user, collection.id, grid.title)

    assert [%{title: ^title}] =
             Learning.list_grids(user, search: "remembered phrase", collection_id: collection.id)

    assert Learning.list_grids(user, search: "remembered phrase", saved_kind: "bookmarks") == []
    {:ok, _} = Dialectic.DbActions.Notes.add_note(grid.title, "2", user)

    assert [%{title: ^title}] =
             Learning.list_grids(user, search: "remembered phrase", saved_kind: "bookmarks")

    :ok = Sharing.remove_invite(grid, user.email, owner)
    assert Learning.list_grids(user, search: "remembered phrase") == []
  end

  test "finds only the viewer's highlight snapshots and personal notes" do
    user = user_fixture()
    other = user_fixture()
    grid = learning_grid_fixture(user, %{is_public: false})
    highlight = highlight(grid, user, "Saved wording", "My annotation")
    highlight(grid, other, "Hidden wording", "Someone else's note")

    for term <- ["saved wording", "my annotation"] do
      assert [%{search_matches: [%{highlight_id: id, node_id: "1", label: "Highlight"}]}] =
               Learning.list_grids(user, search: term, saved_kind: "highlights")

      assert id == highlight.id
    end

    assert Learning.list_grids(user, search: "hidden wording") == []
    assert Learning.list_grids(user, search: "someone else's note") == []
  end

  test "literal wildcard searches and pagination do not duplicate matching grids" do
    user = user_fixture()

    for _ <- 1..3 do
      learning_grid_fixture(user, %{data: data()})
    end

    first = Learning.list_grids(user, search: "50%_increase", limit: 2)
    second = Learning.list_grids(user, search: "50%_increase", limit: 2, offset: 2)
    assert length(first) == 2
    assert length(second) == 1
    assert length(Enum.uniq_by(first ++ second, & &1.title)) == 3
    assert Learning.list_grids(user, search: "50%_different") == []
  end

  defp data do
    %{
      "nodes" => [
        %{"id" => "1", "content" => "Question", "class" => "origin"},
        %{
          "id" => "2",
          "content" => "A remembered phrase with a 50%_increase",
          "class" => "answer"
        },
        %{
          "id" => "3",
          "content" => "Another answer",
          "source_text" => "Original evidence",
          "class" => "answer"
        },
        %{"id" => "4", "content" => "Removed passage", "deleted" => true}
      ],
      "edges" => []
    }
  end

  defp highlight(grid, user, text, note) do
    Repo.insert!(%Highlight{
      mudg_id: grid.title,
      node_id: "1",
      text_source_type: "node",
      selection_start: 0,
      selection_end: 4,
      selected_text_snapshot: text,
      note: note,
      created_by_user_id: user.id
    })
  end
end
