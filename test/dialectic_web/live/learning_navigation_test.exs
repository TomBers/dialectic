defmodule DialecticWeb.LearningNavigationTest do
  use DialecticWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Dialectic.AccountsFixtures
  import Dialectic.LearningFixtures
  alias Dialectic.Learning

  setup :register_and_log_in_user

  test "a matching answer keeps its collection and filters through both grid views", %{
    conn: conn,
    user: user
  } do
    grid = learning_grid_fixture(user, %{is_public: false})
    {:ok, collection} = Learning.create_collection(user, %{name: "Economics"})
    {:ok, _} = Learning.add_grid(user, collection.id, grid.title)
    {:ok, _} = Dialectic.DbActions.Notes.add_note(grid.title, "1", user)

    params = %{
      collection: collection.id,
      saved: "bookmarks",
      q: "learning question",
      include_subfolders: true
    }

    {:ok, library, _} = live(conn, ~p"/my/learning?#{params}")
    match_selector = "#learning-grid-#{Base.url_encode64(grid.title, padding: false)}-match-0"
    path = href(library, match_selector)
    assert URI.decode_query(URI.parse(path).query)["node"] == "1"
    {:ok, reader, _} = live(conn, path)
    assert has_element?(reader, "#reader-header-back-link", "Back to Economics")
    back = href(reader, "#reader-header-back-link")

    assert URI.decode_query(URI.parse(back).query) ==
             Map.new(params, fn {key, value} -> {to_string(key), to_string(value)} end)

    {:ok, editor, _} = live(conn, href(reader, "#reader-workspace-bar-graph"))
    assert href(editor, "#graph-header-back-link") == back
    {:ok, reader, _} = live(conn, href(editor, "#graph-workspace-bar-reader"))
    assert href(reader, "#reader-header-back-link") == back
    {:ok, returned, _} = live(conn, back)
    assert has_element?(returned, "#learning-filter-bookmarks[aria-current='page']")
    assert has_element?(returned, "#learning-search-input[value='learning question']")
    assert has_element?(returned, match_selector)
  end

  test "back navigation defaults to community and rejects unsafe learning locations", %{
    conn: conn,
    user: user
  } do
    grid = learning_grid_fixture(user)
    {:ok, foreign} = Learning.create_collection(user_fixture(), %{name: "Private folder"})

    {:ok, direct_view, _} = live(conn, ~p"/g/#{grid.slug}")
    assert has_element?(direct_view, "#reader-header-back-link", "Back to Community")
    assert href(direct_view, "#reader-header-back-link") == "/community"

    for path <- [
          "https://example.com/my/learning",
          "//example.com/my/learning",
          "/users/log_out",
          "/my/learning?collection=#{foreign.id}"
        ] do
      {:ok, view, _} = live(conn, ~p"/g/#{grid.slug}?#{%{learning: path}}")
      assert has_element?(view, "#reader-header-back-link", "Back to Community")
      assert href(view, "#reader-header-back-link") == "/community"
    end
  end

  test "home directs signed-in creation to My Learning and guests to signup", %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/")
    assert has_element?(view, "#home-hero-start-grid-link[href='/my/learning?new=true']")
    refute has_element?(view, "#new-idea-form")

    assert LazyHTML.from_document(html)
           |> LazyHTML.query("#desktop-new-grid-nav-link")
           |> LazyHTML.attribute("href") == ["/my/learning?new=true"]

    {:ok, private, _} = live(conn, ~p"/my/learning?new=true")
    assert has_element?(private, "#learning-new-grid-form-panel h2", "Create a grid")
    {:ok, _guest, html} = live(build_conn(), ~p"/")

    assert LazyHTML.from_document(html)
           |> LazyHTML.query("#desktop-new-grid-nav-link")
           |> LazyHTML.attribute("href") == []

    assert LazyHTML.from_document(html)
           |> LazyHTML.query("#global-sign-up-link")
           |> LazyHTML.attribute("href") == [
             "/users/register?return_to=%2Fmy%2Flearning%3Fnew%3Dtrue"
           ]
  end

  test "an authenticated resume restores the private question and detail without creating a grid",
       %{conn: conn} do
    {:ok, view, _} = live(conn, ~p"/my/learning?new=true&resume=grid")

    view
    |> element("#learning-new-grid-form")
    |> render_hook("restore_draft", %{content: "An unfinished question", mode: "expert"})

    assert has_element?(view, "#new-idea-input", "An unfinished question")
    assert has_element?(view, "#learning-new-grid-form[data-selected-mode='expert']")

    assert has_element?(
             view,
             "#learning-new-grid-form-answer-level[data-prompt-mode='expert']"
           )

    assert has_element?(view, "#new-idea-create-submit", "Create a grid")
    refute Dialectic.DbActions.Graphs.get_graph_by_title("An unfinished question")

    assert {:error, {:redirect, %{to: "/users/log_in"}}} =
             live(build_conn(), ~p"/my/learning?new=true&resume=grid")
  end

  test "community keeps learning and creation available without duplicate header actions", %{
    conn: conn
  } do
    {:ok, view, _} = live(conn, ~p"/community?category=all&search=remembered%20phrase")

    document = conn |> get(~p"/community") |> html_response(200) |> LazyHTML.from_document()

    assert document |> LazyHTML.query("#my-learning-nav-link") |> LazyHTML.attribute("href") == [
             "/my/learning"
           ]

    assert has_element?(view, "#community-contribute-create-grid")
    refute has_element?(view, "#community-search-my-learning")
    refute has_element?(view, "#community-create-grid")
  end

  defp href(view, selector) do
    view
    |> element(selector)
    |> render()
    |> LazyHTML.from_fragment()
    |> LazyHTML.query(selector)
    |> LazyHTML.attribute("href")
    |> hd()
  end
end
