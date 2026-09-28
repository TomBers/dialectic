defmodule DialecticWeb.LearningFoldersLiveTest do
  use DialecticWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Dialectic.AccountsFixtures
  import Dialectic.LearningFixtures

  alias Dialectic.Learning

  setup :register_and_log_in_user

  setup %{user: user} do
    {:ok, root} = Learning.create_collection(user, %{name: "Economics"})
    {:ok, child} = Learning.create_collection(user, %{name: "Macro"}, root.id)
    {:ok, leaf} = Learning.create_collection(user, %{name: "Inflation"}, child.id)
    %{root: root, child: child, leaf: leaf}
  end

  test "folder creation opens an empty folder with breadcrumbs and a private grid form", %{
    conn: conn,
    user: user,
    root: root,
    child: child
  } do
    {:ok, view, _} = live(conn, ~p"/my/learning?collection=#{child.id}")
    assert has_element?(view, "#learning-folders")
    refute has_element?(view, "#learning-new-grid-form")
    view |> element("#learning-new-folder") |> render_click()
    view |> form("#learning-create-folder", folder: %{name: "Inflation"}) |> render_submit()
    assert has_element?(view, "#learning-create-folder", "has already been taken")
    view |> form("#learning-create-folder", folder: %{name: "Employment"}) |> render_submit()
    folder = Enum.find(Learning.list_collections(user), &(&1.name == "Employment"))
    assert_patch(view, ~p"/my/learning?collection=#{folder.id}&saved=all")
    assert folder.parent_id == child.id
    assert has_element?(view, "#breadcrumbs-#{root.id}", "Economics")
    assert has_element?(view, "#breadcrumbs-#{child.id}", "Macro")
    assert has_element?(view, "#breadcrumbs-#{folder.id} a[aria-current=page]")

    assert view
           |> render()
           |> LazyHTML.from_fragment()
           |> LazyHTML.query("#learning-breadcrumbs > li")
           |> LazyHTML.attribute("id") ==
             [
               "breadcrumbs-root",
               "breadcrumbs-#{root.id}",
               "breadcrumbs-#{child.id}",
               "breadcrumbs-#{folder.id}"
             ]

    assert has_element?(view, "#learning-new-grid-form-context", "folder: Employment")
    assert has_element?(view, "#collections-#{folder.id}[aria-current=page]")
  end

  test "the sidebar expands and collapses nested folders, including on direct navigation", %{
    conn: conn,
    root: root,
    child: child,
    leaf: leaf
  } do
    {:ok, view, _} = live(conn, ~p"/my/learning")
    assert has_element?(view, "#collections-#{root.id}")
    refute has_element?(view, "#collections-#{child.id}")
    view |> element("#learning-expand-#{root.id}") |> render_click()
    assert has_element?(view, "#collections-#{child.id}")
    refute has_element?(view, "#collections-#{leaf.id}")
    view |> element("#learning-expand-#{child.id}") |> render_click()
    assert has_element?(view, "#collections-#{leaf.id}")
    view |> element("#learning-expand-#{root.id}") |> render_click()
    refute has_element?(view, "#collections-#{leaf.id}")
    {:ok, direct, _} = live(conn, ~p"/my/learning?collection=#{leaf.id}")
    assert has_element?(direct, "#collections-#{leaf.id}[aria-current=page]")
    assert has_element?(direct, "#learning-expand-#{root.id}[aria-expanded=true]")
    assert has_element?(direct, "#learning-expand-#{child.id}[aria-expanded=true]")
  end

  test "subfolder filtering persists through bookmarks and search and shows membership paths", %{
    conn: conn,
    user: user,
    root: root,
    leaf: leaf
  } do
    grid = learning_grid_fixture(user, %{title: "Inflation notes"})
    {:ok, _} = Learning.add_grid(user, leaf.id, grid.title)
    {:ok, _} = Dialectic.DbActions.Notes.add_note(grid.title, "1", user)
    {:ok, view, _} = live(conn, ~p"/my/learning?collection=#{root.id}")
    refute has_element?(view, grid_selector(grid))

    view
    |> form("#learning-subfolder-scope", scope: %{include_subfolders: true})
    |> render_change()

    assert has_element?(view, grid_selector(grid))

    assert has_element?(
             view,
             grid_selector(grid, "-topic-#{leaf.id}"),
             "Economics / Macro / Inflation"
           )

    refute has_element?(view, grid_selector(grid, "-remove"))
    view |> element("#learning-filter-bookmarks") |> render_click()
    assert has_element?(view, "#learning-include-subfolders[checked]")
    assert has_element?(view, grid_selector(grid))
    view |> form("#learning-search", q: "inflation") |> render_change()
    assert has_element?(view, grid_selector(grid))
    assert has_element?(view, "#learning-include-subfolders[checked]")

    view |> element("#learning-filter-all") |> render_click()
    assert has_element?(view, "#learning-search-input[value='inflation']")
    assert has_element?(view, "#learning-include-subfolders[checked]")
    assert has_element?(view, grid_selector(grid))

    view
    |> form("#learning-subfolder-scope", scope: %{include_subfolders: false})
    |> render_change()

    refute has_element?(view, grid_selector(grid))
  end

  test "Move offers safe destinations and drag events cannot bypass ownership or cycle checks", %{
    conn: conn,
    user: user,
    root: root,
    child: child,
    leaf: leaf
  } do
    {:ok, destination} = Learning.create_collection(user, %{name: "Revision"})
    {:ok, foreign} = Learning.create_collection(user_fixture(), %{name: "Foreign"})
    {:ok, view, _} = live(conn, ~p"/my/learning?collection=#{child.id}")
    refute has_element?(view, "#learning-move-folder")
    view |> element("#learning-edit-button") |> render_click()
    assert has_element?(view, "#learning-edit-collection #learning-move-folder")
    view |> element("#learning-move-folder") |> render_click()
    refute has_element?(view, "#learning-move-folder-parent option[value='#{child.id}']")
    refute has_element?(view, "#learning-move-folder-parent option[value='#{leaf.id}']")
    refute has_element?(view, "#learning-move-folder-parent option[value='#{foreign.id}']")

    view
    |> form("#learning-move-folder-form", move: %{parent_id: destination.id})
    |> render_submit()

    refute has_element?(view, "#learning-move-folder-modal")
    assert Learning.get_collection(user, child.id).parent_id == destination.id
    assert has_element?(view, "#breadcrumbs-#{destination.id}")
    refute has_element?(view, "#breadcrumbs-#{root.id}")
    render_hook(view, "drop_folder", %{collection_id: child.id, parent_id: leaf.id})
    assert Learning.get_collection(user, child.id).parent_id == destination.id
    render_hook(view, "drop_folder", %{collection_id: child.id, parent_id: foreign.id})
    assert Learning.get_collection(user, child.id).parent_id == destination.id
    render_hook(view, "drop_folder", %{collection_id: child.id, parent_id: "root"})
    assert Learning.get_collection(user, child.id).parent_id == nil
    refute has_element?(view, "#breadcrumbs-#{destination.id}")
  end

  test "filing a grid into a folder removes it from the parent and updates the counts", %{
    conn: conn,
    user: user,
    root: root,
    leaf: leaf
  } do
    grid = learning_grid_fixture(user)
    {:ok, _} = Learning.add_grid(user, root.id, grid.title)
    {:ok, view, _} = live(conn, ~p"/my/learning?collection=#{root.id}")
    assert has_element?(view, grid_selector(grid))
    render_hook(view, "drop_grid", %{title: grid.title, collection_id: leaf.id})
    refute has_element?(view, grid_selector(grid))
    assert has_element?(view, "#collections-#{root.id} [aria-label='0 grids']")

    view
    |> form("#learning-subfolder-scope", scope: %{include_subfolders: true})
    |> render_change()

    assert has_element?(view, grid_selector(grid))
    view |> element(grid_selector(grid, "-topic-#{leaf.id}")) |> render_click()
    assert has_element?(view, grid_selector(grid))
    assert has_element?(view, "#collections-#{leaf.id} [aria-label='1 grid']")
    view |> element(grid_selector(grid, "-organise")) |> render_click()

    view
    |> form("#learning-organise-form", membership: %{collection_id: root.id})
    |> render_submit()

    refute has_element?(view, grid_selector(grid))
    assert has_element?(view, "#learning-new-grid-form")
    assert [%{title: title}] = Learning.list_grids(user, collection_id: root.id)
    assert title == grid.title
  end

  test "deleting a folder returns to its parent and keeps the grid", %{
    conn: conn,
    user: user,
    root: root,
    child: child,
    leaf: leaf
  } do
    grid = learning_grid_fixture(user)
    {:ok, _} = Learning.add_grid(user, leaf.id, grid.title)
    {:ok, view, _} = live(conn, ~p"/my/learning?collection=#{child.id}")
    view |> element("#learning-edit-button") |> render_click()
    view |> element("#learning-delete-collection") |> render_click()
    assert_patch(view, ~p"/my/learning?collection=#{root.id}")
    assert Learning.get_collection(user, child.id) == nil
    assert Learning.get_collection(user, leaf.id) == nil
    view |> element("#learning-all-grids") |> render_click()
    assert has_element?(view, grid_selector(grid))
  end

  test "private grids created inside a folder are filed only there", %{
    conn: conn,
    user: user,
    root: root,
    leaf: leaf
  } do
    question = "Folder question #{System.unique_integer([:positive])}"
    {:ok, view, _} = live(conn, ~p"/my/learning?collection=#{leaf.id}")
    view |> form("#learning-new-grid-form", vertex: %{content: question}) |> render_submit()
    view |> form("#learning-new-grid-form", vertex: %{content: question}) |> render_submit()
    assert_redirect(view, 2_000)

    assert [%{title: ^question, is_public: false}] =
             Learning.list_grids(user, collection_id: leaf.id)

    assert Learning.list_grids(user, collection_id: root.id) == []

    assert [%{title: ^question}] =
             Learning.list_grids(user, collection_id: root.id, include_subfolders: true)
  end

  test "folder tools keep one form active and preserve an unfinished grid question", %{
    conn: conn,
    leaf: leaf
  } do
    {:ok, view, _} = live(conn, ~p"/my/learning?collection=#{leaf.id}")

    view
    |> element("#new-idea-input")
    |> render_change(%{"vertex" => %{"content" => "An unfinished question"}})

    view |> element("#learning-new-folder") |> render_click()
    assert has_element?(view, "#learning-create-folder")
    assert has_element?(view, "#learning-create-grid[hidden]")
    view |> element("#learning-edit-button") |> render_click()
    refute has_element?(view, "#learning-create-folder")
    assert has_element?(view, "#learning-edit-collection")
    view |> element("#learning-cancel-edit") |> render_click()
    assert has_element?(view, "#learning-create-grid:not([hidden])")
    assert has_element?(view, "#new-idea-input", "An unfinished question")
  end

  test "folder-only collections direct users to their folders and leaf folders omit subfolder controls",
       %{conn: conn, user: user, root: root, leaf: leaf} do
    grid = learning_grid_fixture(user)
    {:ok, _} = Learning.add_grid(user, leaf.id, grid.title)
    {:ok, view, _} = live(conn, ~p"/my/learning?collection=#{root.id}")
    assert has_element?(view, "#learning-folder-empty-title")
    assert has_element?(view, "#learning-include-subfolders")
    {:ok, leaf_view, _} = live(conn, ~p"/my/learning?collection=#{leaf.id}")
    refute has_element?(leaf_view, "#learning-include-subfolders")
    assert has_element?(leaf_view, grid_selector(grid, "-manage") <> ":not([open])")
    leaf_view |> element(grid_selector(grid, "-organise")) |> render_click()
    assert has_element?(leaf_view, "#learning-filing-hint")
    leaf_view |> element("#learning-cancel-organise") |> render_click()
    refute has_element?(leaf_view, "#learning-organise-modal")
  end

  defp grid_selector(grid, suffix \\ ""),
    do: "#learning-grid-" <> Base.url_encode64(grid.title, padding: false) <> suffix
end
