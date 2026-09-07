defmodule Dialectic.QuestionPagesTest do
  use Dialectic.DataCase, async: true
  import Dialectic.QuestionPageFixtures
  alias Dialectic.QuestionPages
  alias Dialectic.QuestionPages.Source

  setup do
    %{admin: admin_fixture(), graph: graph_fixture()}
  end

  test "a draft stays private and publication requires review", %{admin: admin, graph: graph} do
    page = draft_fixture(admin, graph)
    assert QuestionPages.get_public(page.slug) == nil
    assert {:error, :review_required} = QuestionPages.save(admin, page, page.draft, :publish)
    assert {:ok, published} = QuestionPages.save(admin, page, page.draft, :publish, true)

    assert QuestionPages.get_public(page.slug).published["content"]["summary"] ==
             page.draft["summary"]

    assert Enum.any?(QuestionPages.list_public(), &(&1.slug == published.slug))

    assert {:ok, edited} =
             QuestionPages.save(admin, published, %{"summary" => "Unpublished revision"}, :draft)

    assert edited.draft["summary"] == "Unpublished revision"

    refute QuestionPages.get_public(page.slug).published["content"]["summary"] ==
             "Unpublished revision"
  end

  test "changed nodes preserve the published snapshot and block stale drafts", %{
    admin: admin,
    graph: graph
  } do
    page = draft_fixture(admin, graph)
    {:ok, page} = QuestionPages.save(admin, page, page.draft, :publish, true)

    data =
      Map.update!(graph.data, "nodes", fn nodes ->
        Enum.map(nodes, &Map.put(&1, "content", &1["content"] <> " Changed."))
      end)

    graph = graph |> Ecto.Changeset.change(data: data) |> Repo.update!()
    assert QuestionPages.stale?(page, graph)
    assert QuestionPages.published_stale?(page, graph)
    assert {:error, :source_changed} = QuestionPages.save(admin, page, page.draft, :publish, true)
    assert QuestionPages.get_public(page.slug).published == page.published

    assert {:error, :source_changed} =
             QuestionPages.save_generated(admin, page.source, page.lock_version, page.draft)
  end

  test "other editors cannot overwrite a newer revision", %{admin: admin, graph: graph} do
    page = draft_fixture(admin, graph)

    assert {:ok, saved} =
             QuestionPages.save(admin, page, %{"summary" => "First editor saved"}, :draft)

    assert {:error, :conflict} =
             QuestionPages.save(admin, page, %{"summary" => "Stale editor"}, :publish, true)

    assert {:error, :conflict} =
             QuestionPages.save_generated(admin, page.source, page.lock_version, page.draft)

    assert {:ok, _, current} = QuestionPages.editor(admin, graph.slug)
    assert current.draft == saved.draft
  end

  test "admin checks use current permissions and private grids cannot be published", %{
    admin: admin,
    graph: graph
  } do
    user = Dialectic.AccountsFixtures.user_fixture()
    page = draft_fixture(admin, graph)
    assert {:error, :unavailable} = QuestionPages.prepare(user, graph.slug, selection())
    assert {:error, :forbidden} = QuestionPages.save(user, page, page.draft, :publish, true)
    assert {:error, :forbidden} = QuestionPages.unpublish(user, page)
    admin |> Ecto.Changeset.change(is_admin: false) |> Repo.update!()
    assert {:error, :forbidden} = QuestionPages.save(admin, page, page.draft, :publish, true)
  end

  for change <- [%{is_public: false}, %{is_published: false}, %{is_deleted: true}] do
    test "public queries hide pages when the grid changes to #{inspect(change)}", %{
      admin: admin,
      graph: graph
    } do
      page = draft_fixture(admin, graph)
      {:ok, page} = QuestionPages.save(admin, page, page.draft, :publish, true)
      graph |> Ecto.Changeset.change(unquote(Macro.escape(change))) |> Repo.update!()
      assert QuestionPages.get_public(page.slug) == nil
      refute Enum.any?(QuestionPages.list_public(), &(&1.slug == page.slug))
      assert {:error, :unavailable} = QuestionPages.save(admin, page, page.draft, :publish, true)
    end
  end

  test "unpublishing removes public access and keeps the draft", %{admin: admin, graph: graph} do
    page = draft_fixture(admin, graph)
    {:ok, published} = QuestionPages.save(admin, page, page.draft, :publish, true)
    {:ok, unpublished} = QuestionPages.unpublish(admin, published)
    assert QuestionPages.get_public(page.slug) == nil
    assert unpublished.draft == page.draft
    assert unpublished.first_published_at != nil
  end

  test "selected nodes and source IDs must belong to the captured grid", %{
    admin: admin,
    graph: graph
  } do
    assert {:error, :invalid_selection} =
             QuestionPages.prepare(admin, graph.slug, %{selection() | "answer" => "foreign-node"})

    page = draft_fixture(admin, graph)
    attrs = put_in(page.draft, ["evidence", Access.at(0), "source_ids"], ["invented-link"])
    assert {:error, :invalid_references} = QuestionPages.save(admin, page, attrs, :publish, true)
    attrs = put_in(page.draft, ["paths", Access.at(0), "node_id"], "foreign-node")
    assert {:error, :invalid_references} = QuestionPages.save(admin, page, attrs, :draft)
    assert page.source["hash"] == Source.hash(graph)
  end
end
