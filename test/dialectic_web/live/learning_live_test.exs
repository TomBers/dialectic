defmodule DialecticWeb.LearningLiveTest do
  use DialecticWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Dialectic.AccountsFixtures
  import Dialectic.LearningFixtures

  alias Dialectic.Learning

  test "requires authentication", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/users/log_in"}}} = live(conn, ~p"/my/learning")
  end

  describe "My Learning" do
    setup :register_and_log_in_user

    setup %{user: user} do
      Dialectic.Repo.insert!(%Dialectic.Learning.Workspace{
        user_id: user.id,
        topics_initialized_at: DateTime.utc_now() |> DateTime.truncate(:second)
      })

      :ok
    end

    test "creates, edits, and deletes a collection through its forms", %{conn: conn, user: user} do
      {:ok, view, html} = live(conn, ~p"/my/learning")
      assert has_element?(view, "#learning-header")
      assert has_element?(view, "#learning-activity-link[href='/activity']")
      assert has_element?(view, "#learning-topics-empty:only-child")
      assert has_element?(view, "#learning-collections-empty:only-child")

      assert html
             |> LazyHTML.from_document()
             |> LazyHTML.query("#my-learning-nav-link")
             |> LazyHTML.attribute("href") == ["/my/learning"]

      view
      |> form("#learning-create-collection",
        collection: %{name: "Economics", description: "How economies work"}
      )
      |> render_submit()

      [collection] = Learning.list_collections(user)
      assert_patch(view, ~p"/my/learning?collection=#{collection.id}")
      assert has_element?(view, "#learning-section-title", "Economics")
      assert has_element?(view, "#learning-collection-summary", "How economies work")
      assert has_element?(view, "#collections-#{collection.id}[aria-current='page']")

      assert has_element?(view, "#learning-collections #collections-#{collection.id}")
      refute has_element?(view, "#learning-topics #collections-#{collection.id}")
      refute has_element?(view, "#learning-collections-empty:only-child")

      assert has_element?(
               view,
               "#learning-collection-origin[data-origin='manual']",
               "Created by you"
             )

      assert has_element?(
               view,
               "#learning-new-grid[href='/?collection=#{collection.id}&focus=grid#start-here']"
             )

      view |> element("#learning-edit-button") |> render_click()

      view
      |> form("#learning-edit-collection",
        collection: %{name: "Economic history", description: "Reading notes"}
      )
      |> render_submit()

      assert has_element?(view, "#learning-section-title", "Economic history")
      {:ok, revisited, _} = live(conn, ~p"/my/learning?collection=#{collection.id}")
      assert has_element?(revisited, "#learning-collection-summary", "Reading notes")
      assert has_element?(revisited, "#learning-collection-origin[data-origin='manual']")
      assert has_element?(revisited, "#learning-collections #collections-#{collection.id}")
      revisited |> element("#learning-edit-button") |> render_click()
      revisited |> element("#learning-delete-collection") |> render_click()
      assert_patch(revisited, ~p"/my/learning")
      assert Learning.list_collections(user) == []
      assert has_element?(revisited, "#learning-collections-empty:only-child")
    end

    test "adds existing grids, searches a collection, and removes membership without deleting the grid",
         %{conn: conn, user: user} do
      grid =
        learning_grid_fixture(user, %{title: "Why does inflation happen?", tags: ["economics"]})

      other = learning_grid_fixture(user, %{title: "Learning Spanish"})
      {:ok, collection} = Learning.create_collection(user, %{name: "Economics"})
      {:ok, view, _} = live(conn, ~p"/my/learning?collection=#{collection.id}")
      view |> element("#learning-add-existing") |> render_click()
      assert has_element?(view, grid_selector(grid, "-add"))
      view |> form("#learning-search", q: "inflation") |> render_change()
      refute has_element?(view, grid_selector(other))
      view |> element(grid_selector(grid, "-add")) |> render_click()
      refute has_element?(view, grid_selector(grid))
      view |> element("#learning-done-adding") |> render_click()
      assert has_element?(view, grid_selector(grid))
      assert has_element?(view, grid_selector(grid, "-open") <> "[href='/g/#{grid.slug}']")
      view |> form("#learning-search", q: "economics") |> render_change()
      assert has_element?(view, grid_selector(grid))
      {:ok, revisited, _} = live(conn, ~p"/my/learning?collection=#{collection.id}")
      assert has_element?(revisited, grid_selector(grid))
      revisited |> element(grid_selector(grid, "-remove")) |> render_click()
      refute has_element?(revisited, grid_selector(grid))
      revisited |> element("#learning-all-grids") |> render_click()
      assert has_element?(revisited, grid_selector(grid))
    end

    test "cannot access or mutate another user's collections", %{conn: conn, user: user} do
      other = user_fixture()
      {:ok, collection} = Learning.create_collection(other, %{name: "Private collection"})
      grid = learning_grid_fixture(user)

      assert {:error, {:live_redirect, %{to: "/my/learning"}}} =
               live(conn, ~p"/my/learning?collection=#{collection.id}")

      {:ok, view, _} = live(conn, ~p"/my/learning")
      refute has_element?(view, "#collections-#{collection.id}")
      render_click(view, "add_grid", %{"title" => grid.title, "collection_id" => collection.id})
      assert Learning.list_grids(other, collection_id: collection.id) == []
    end

    test "validation errors preserve the collection form", %{conn: conn, user: user} do
      {:ok, _} = Learning.create_collection(user, %{name: "Economics"})
      {:ok, view, _} = live(conn, ~p"/my/learning")

      view
      |> form("#learning-create-collection", collection: %{name: " economics "})
      |> render_submit()

      assert has_element?(view, "#learning-create-collection", "has already been taken")
      assert length(Learning.list_collections(user)) == 1
    end

    test "pagination appends grids and changing the search resets the stream", %{
      conn: conn,
      user: user
    } do
      for n <- 1..25,
          do:
            learning_grid_fixture(user, %{
              title: "Revision #{String.pad_leading(to_string(n), 2, "0")}"
            })

      {:ok, view, _} = live(conn, ~p"/my/learning")
      assert has_element?(view, "#learning-load-more")
      view |> element("#learning-load-more") |> render_click()
      refute has_element?(view, "#learning-load-more")

      assert view
             |> render()
             |> LazyHTML.from_fragment()
             |> LazyHTML.query("#learning-grids > article")
             |> Enum.count() == 25

      view |> form("#learning-search", q: "Revision 25") |> render_change()

      assert view
             |> render()
             |> LazyHTML.from_fragment()
             |> LazyHTML.query("#learning-grids > article")
             |> Enum.count() == 1
    end

    test "new grids started in a collection are filed there", %{conn: conn, user: user} do
      {:ok, collection} = Learning.create_collection(user, %{name: "Economics"})
      question = "Economics question #{System.unique_integer([:positive])}"
      {:ok, view, _} = live(conn, ~p"/?collection=#{collection.id}&focus=grid")
      assert has_element?(view, "#home-collection-context", "Economics")
      view |> form("#new-idea-form", vertex: %{content: question}) |> render_submit()
      view |> form("#new-idea-form", vertex: %{content: question}) |> render_submit()
      {path, _flash} = assert_redirect(view, 2_000)

      assert [%{title: ^question, slug: slug}] =
               Learning.list_grids(user, collection_id: collection.id)

      assert path == "/g/#{slug}"
    end

    test "dragging and the Organise dialog add grids to topics with ownership checks", %{
      conn: conn,
      user: user
    } do
      grid = learning_grid_fixture(user)
      {:ok, economics} = Learning.create_collection(user, %{name: "Economics"})
      {:ok, revision} = Learning.create_collection(user, %{name: "Revision"})
      {:ok, foreign} = Learning.create_collection(user_fixture(), %{name: "Someone else's topic"})
      {:ok, view, _} = live(conn, ~p"/my/learning")
      assert has_element?(view, grid_selector(grid, "-drag") <> "[draggable=true]")

      assert has_element?(
               view,
               "#collections-#{economics.id}[data-learning-drop='#{economics.id}']"
             )

      render_hook(view, "drop_grid", %{title: grid.title, collection_id: economics.id})
      assert [%{title: title}] = Learning.list_grids(user, collection_id: economics.id)
      assert title == grid.title
      view |> element(grid_selector(grid, "-organise")) |> render_click()

      view
      |> form("#learning-organise-form", membership: %{collection_id: revision.id})
      |> render_submit()

      assert [%{title: ^title}] = Learning.list_grids(user, collection_id: revision.id)
      refute has_element?(view, "#learning-organise-modal")
      render_hook(view, "drop_grid", %{title: grid.title, collection_id: foreign.id})
      assert Learning.list_grids(user, collection_id: foreign.id) == []
      assert has_element?(view, grid_selector(grid))
    end

    test "bookmarks and highlights follow their grid's topic and link to their original context",
         %{conn: conn, user: user} do
      grid = learning_grid_fixture(user)
      {:ok, bookmark} = Dialectic.DbActions.Notes.add_note(grid.title, "1", user)

      highlight =
        Dialectic.Repo.insert!(%Dialectic.Highlights.Highlight{
          mudg_id: grid.title,
          node_id: "1",
          text_source_type: "node",
          selection_start: 0,
          selection_end: 4,
          selected_text_snapshot: "A useful explanation",
          note: "Remember this",
          created_by_user_id: user.id
        })

      {:ok, economics} = Learning.create_collection(user, %{name: "Economics"})
      {:ok, history} = Learning.create_collection(user, %{name: "History"})
      {:ok, _} = Learning.add_grid(user, economics.id, grid.title)
      {:ok, view, _} = live(conn, ~p"/my/learning?collection=#{economics.id}")

      assert has_element?(
               view,
               "#learning-bookmark-#{bookmark.id}-open[href='/g/#{grid.slug}?node=1']"
             )

      assert has_element?(view, "#learning-highlight-#{highlight.id}", "Remember this")
      view |> element("#learning-filter-highlights") |> render_click()
      assert has_element?(view, "#learning-highlight-#{highlight.id}")
      refute has_element?(view, "#learning-bookmark-#{bookmark.id}")
      view |> element("#collections-#{history.id}") |> render_click()
      refute has_element?(view, grid_selector(grid))
      view |> element("#collections-#{economics.id}") |> render_click()
      assert has_element?(view, "#learning-highlight-#{highlight.id}")
      view |> element("#learning-highlight-#{highlight.id}-remove") |> render_click()
      refute has_element?(view, grid_selector(grid))
      view |> element("#learning-filter-bookmarks") |> render_click()
      view |> element("#learning-bookmark-#{bookmark.id}-remove") |> render_click()
      refute has_element?(view, grid_selector(grid))
      view |> element("#learning-filter-all") |> render_click()
      assert has_element?(view, grid_selector(grid))
    end

    test "grid management includes private grids, visibility, deletion, and cancellation", %{
      conn: conn,
      user: user
    } do
      grid = learning_grid_fixture(user, %{is_public: false})
      {:ok, collection} = Learning.create_collection(user, %{name: "Revision"})
      {:ok, _} = Learning.add_grid(user, collection.id, grid.title)
      {:ok, view, _} = live(conn, ~p"/my/learning?collection=#{collection.id}")
      assert has_element?(view, grid_selector(grid), "Private grid")
      view |> element(grid_selector(grid, "-visibility")) |> render_click()
      assert Dialectic.Repo.get!(Dialectic.Accounts.Graph, grid.title).is_public
      view |> element(grid_selector(grid, "-delete")) |> render_click()
      view |> element("#learning-cancel-delete") |> render_click()
      refute has_element?(view, "#learning-delete-modal")
      assert has_element?(view, grid_selector(grid))
      view |> element(grid_selector(grid, "-delete")) |> render_click()
      view |> element("#learning-confirm-delete") |> render_click()
      refute has_element?(view, grid_selector(grid))
      assert Dialectic.Repo.get!(Dialectic.Accounts.Graph, grid.title).is_deleted
      assert [%{grid_count: 0}] = Learning.list_collections(user)
    end

    test "cannot manage someone else's grid even with crafted events", %{conn: conn, user: user} do
      grid = learning_grid_fixture(user_fixture())
      {:ok, _} = Dialectic.DbActions.Notes.add_note(grid.title, "1", user)
      {:ok, view, _} = live(conn, ~p"/my/learning")
      refute has_element?(view, grid_selector(grid, "-delete"))
      refute has_element?(view, grid_selector(grid, "-visibility"))
      render_click(view, "toggle_visibility", %{title: grid.title})
      render_click(view, "show_delete_grid", %{title: grid.title})
      render_click(view, "delete_grid")
      unchanged = Dialectic.Repo.get!(Dialectic.Accounts.Graph, grid.title)
      assert unchanged.is_public
      refute unchanged.is_deleted
    end
  end

  test "a first visit organises existing tags and saved material into topic collections", %{
    conn: conn
  } do
    user = user_fixture()
    grid = learning_grid_fixture(user, %{tags: ["economics"]})
    {:ok, bookmark} = Dialectic.DbActions.Notes.add_note(grid.title, "1", user)
    {:ok, manual} = Learning.create_collection(user, %{name: "Revision"})
    conn = log_in_user(conn, user)
    {:ok, view, _} = live(conn, ~p"/my/learning")
    topic = Enum.find(Learning.list_collections(user), &(&1.origin == :tags))
    assert topic.name == "Economics"
    assert topic.grid_count == 1

    assert has_element?(
             view,
             "#learning-topics #topics-#{topic.id}[data-learning-drop='#{topic.id}']"
           )

    assert has_element?(
             view,
             "#learning-collections #collections-#{manual.id}[data-learning-drop='#{manual.id}']"
           )

    refute has_element?(view, "#learning-collections #topics-#{topic.id}")
    refute has_element?(view, "#learning-topics #collections-#{manual.id}")

    view |> element("#topics-#{topic.id}") |> render_click()

    assert has_element?(
             view,
             "#learning-collection-origin[data-origin='tags']",
             "Topic · From your grid tags"
           )

    assert has_element?(view, "#learning-edit-button", "Edit topic")

    view |> element("#learning-edit-button") |> render_click()

    view
    |> form("#learning-edit-collection", collection: %{name: "Economic thinking"})
    |> render_submit()

    assert has_element?(view, "#learning-section-title", "Economic thinking")
    assert has_element?(view, "#learning-collection-origin[data-origin='tags']")
    assert has_element?(view, "#learning-topics #topics-#{topic.id}", "Economic thinking")
    assert has_element?(view, grid_selector(grid))
    assert has_element?(view, "#learning-bookmark-#{bookmark.id}")

    view |> element(grid_selector(grid, "-organise")) |> render_click()

    assert has_element?(
             view,
             "#learning-organise-target optgroup[label='Topics'] option[value='#{topic.id}']"
           )

    assert has_element?(
             view,
             "#learning-organise-target optgroup[label='Collections'] option[value='#{manual.id}']"
           )

    view
    |> form("#learning-organise-form", membership: %{collection_id: manual.id})
    |> render_submit()

    view |> element("#learning-filter-bookmarks") |> render_click()
    view |> element("#collections-#{manual.id}") |> render_click()
    assert_patch(view, ~p"/my/learning?collection=#{manual.id}&saved=bookmarks")
    assert has_element?(view, "#learning-bookmark-#{bookmark.id}")
    view |> element("#topics-#{topic.id}") |> render_click()
    assert_patch(view, ~p"/my/learning?collection=#{topic.id}&saved=bookmarks")

    view |> element(grid_selector(grid, "-remove")) |> render_click()
    render_hook(view, "drop_grid", %{title: grid.title, collection_id: topic.id})
    assert has_element?(view, grid_selector(grid))
    view |> element(grid_selector(grid, "-remove")) |> render_click()
    {:ok, revisited, _} = live(conn, ~p"/my/learning?collection=#{topic.id}")
    assert has_element?(revisited, "#learning-collection-origin[data-origin='tags']")
    refute has_element?(revisited, grid_selector(grid))
    assert has_element?(revisited, "#learning-topics #topics-#{topic.id}")
    assert [%{title: title}] = Learning.list_grids(user, collection_id: manual.id)
    assert title == grid.title
  end

  defp grid_selector(grid, suffix \\ ""),
    do: "#learning-grid-" <> Base.url_encode64(grid.title, padding: false) <> suffix
end
