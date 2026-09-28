defmodule DialecticWeb.LearningCreationTest do
  use DialecticWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Dialectic.AccountsFixtures
  import Dialectic.LearningFixtures

  alias Dialectic.DbActions.{Graphs, Sharing}
  alias Dialectic.Learning
  alias Dialectic.Repo

  setup :register_and_log_in_user

  test "the form creates an owned private grid with the chosen depth", %{conn: conn, user: user} do
    question = "Private exploration #{System.unique_integer([:positive])}"
    {:ok, view, _html} = live(conn, ~p"/my/learning")

    assert has_element?(view, "#learning-new-grid-form-panel label", "Start a private grid")
    refute has_element?(view, "#new-idea-level-step")

    view
    |> form("#learning-new-grid-form", vertex: %{content: question})
    |> render_submit()

    assert has_element?(view, "#new-idea-level-step")
    assert has_element?(view, "#new-idea-create-submit", "Create private grid")
    refute has_element?(view, "#home-public-grid-note")
    refute Graphs.get_graph_by_title(question)
    view |> element("#new-idea-mode-expert") |> render_click()
    view |> form("#learning-new-grid-form", vertex: %{content: question}) |> render_submit()

    {path, _flash} = assert_redirect(view, 2_000)
    graph = Graphs.get_graph_by_title(question)
    refute graph.is_public
    assert graph.user_id == user.id
    assert graph.prompt_mode == "expert"
    assert URI.parse(path).path == "/g/#{graph.slug}"
    assert GraphManager.find_node_by_id(graph.title, "1").content == "## " <> question
    assert GraphManager.find_node_by_id(graph.title, "2").response_level == "expert"
    assert Sharing.can_access?(user, graph)
    refute Sharing.can_access?(nil, graph)
    refute Sharing.can_access?(user_fixture(), graph)
    assert Graphs.all_graphs_with_notes(question) == []

    {:ok, revisited, _html} = live(conn, ~p"/my/learning")
    assert has_element?(revisited, "#learning-grids a[href^='#{URI.parse(path).path}?']")

    for suffix <- ["", "/graph"] do
      assert {:error, {:redirect, %{to: "/"}}} =
               live(build_conn(), URI.parse(path).path <> suffix)
    end
  end

  test "a public matching question stays public while My Learning creates a separate private grid",
       %{
         conn: conn,
         user: user
       } do
    original = learning_grid_fixture(user_fixture())
    {:ok, view, _html} = live(conn, ~p"/my/learning")

    view
    |> form("#learning-new-grid-form", vertex: %{content: original.title})
    |> render_submit()

    view
    |> form("#learning-new-grid-form", vertex: %{content: original.title})
    |> render_submit(%{"vertex" => %{"is_public" => "true", "user_id" => original.user_id}})

    {path, _flash} = assert_redirect(view, 2_000)

    graph =
      Graphs.get_graph_by_slug_or_title(String.replace_prefix(URI.parse(path).path, "/g/", ""))

    refute graph.is_public
    assert graph.user_id == user.id
    assert graph.title != original.title
    assert Repo.reload!(original).is_public
    assert Repo.reload!(original).data == original.data
    assert GraphManager.find_node_by_id(graph.title, "1").content == "## " <> original.title
  end

  test "blank questions and unsupported depths keep the form without creating a grid", %{
    conn: conn,
    user: user
  } do
    {:ok, view, _html} = live(conn, ~p"/my/learning")
    view |> form("#learning-new-grid-form", vertex: %{content: "  "}) |> render_submit()
    refute has_element?(view, "#new-idea-level-step")
    refute has_element?(view, "#learning-new-grid-form-progress")

    view
    |> form("#learning-new-grid-form", vertex: %{content: "A question to keep"})
    |> render_submit()

    view |> element("#new-idea-mode-expert") |> render_click(%{"mode" => "unsupported"})

    view
    |> form("#learning-new-grid-form", vertex: %{content: "A question to keep"})
    |> render_submit()

    assert has_element?(view, "#new-idea-input", "A question to keep")
    assert has_element?(view, "#flash-error", "choose an answer depth")
    assert Learning.list_grids(user) == []
  end

  test "a private grid can be created directly in an automatically generated topic", %{
    conn: conn,
    user: user
  } do
    learning_grid_fixture(user, %{tags: ["economics"]})
    {:ok, _} = Learning.initialize_topics(user)
    [topic] = Learning.list_collections(user)
    assert topic.origin == :tags
    {:ok, view, _html} = live(conn, ~p"/my/learning?collection=#{topic.id}")
    view |> element("#learning-new-grid-tab") |> render_click()
    question = "Private topic question #{System.unique_integer([:positive])}"

    view
    |> form("#learning-new-grid-form", vertex: %{content: question})
    |> render_submit()

    view |> form("#learning-new-grid-form", vertex: %{content: question}) |> render_submit()

    assert_redirect(view, 2_000)

    assert Enum.any?(Learning.list_grids(user, collection_id: topic.id), fn grid ->
             grid.title == question && grid.is_public == false
           end)
  end

  test "an empty workspace or collection opens directly on the creation form", %{
    conn: conn,
    user: user
  } do
    {:ok, view, _html} = live(conn, ~p"/my/learning")
    assert has_element?(view, "#learning-content #learning-new-grid-form")
    assert has_element?(view, "#learning-new-grid-tab[aria-current='page']")
    refute has_element?(view, "#learning-header form")
    refute has_element?(view, "#learning-grid-browser")
    refute has_element?(view, "#learning-search")
    refute has_element?(view, "#learning-organise-hint")

    learning_grid_fixture(user)
    {:ok, collection} = Learning.create_collection(user, %{name: "New subject"})
    {:ok, view, _html} = live(conn, ~p"/my/learning?collection=#{collection.id}")
    assert has_element?(view, "#learning-new-grid-form-context", "New subject")
    refute has_element?(view, "#learning-grid-browser")
    assert has_element?(view, "#learning-add-existing")
  end

  test "New grid keeps the selected collection and returning to All grids restores its contents",
       %{
         conn: conn,
         user: user
       } do
    grid = learning_grid_fixture(user)
    {:ok, collection} = Learning.create_collection(user, %{name: "Economics"})
    {:ok, _} = Learning.add_grid(user, collection.id, grid.title)
    {:ok, view, _html} = live(conn, ~p"/my/learning?collection=#{collection.id}&saved=highlights")
    refute has_element?(view, "#learning-new-grid-form")
    assert has_element?(view, "#learning-no-grids", "No highlights here yet")

    view |> element("#learning-new-grid-tab") |> render_click()
    assert has_element?(view, "#learning-new-grid-form-context", "Economics")
    assert has_element?(view, "#learning-new-grid-tab[aria-current='page']")
    refute has_element?(view, "#learning-grid-browser")

    assert view |> assert_patch() |> URI.parse() |> Map.fetch!(:query) |> URI.decode_query() ==
             %{"collection" => to_string(collection.id), "new" => "true"}

    view |> element("#learning-filter-all") |> render_click()
    assert has_element?(view, "#learning-grids a[href^='/g/#{grid.slug}?']")
    assert has_element?(view, "#learning-filter-all[aria-current='page']")
    refute has_element?(view, "#learning-new-grid-form")

    view |> form("#learning-search", q: "nothing matches") |> render_change()
    assert has_element?(view, "#learning-no-grids", "No matching grids")
    refute has_element?(view, "#learning-new-grid-form")

    view |> element("#learning-new-grid-tab") |> render_click()
    question = "New collection grid #{System.unique_integer([:positive])}"
    view |> form("#learning-new-grid-form", vertex: %{content: question}) |> render_submit()
    view |> form("#learning-new-grid-form", vertex: %{content: question}) |> render_submit()
    assert_redirect(view, 2_000)

    assert Enum.any?(
             Learning.list_grids(user, collection_id: collection.id),
             &(&1.title == question && !&1.is_public)
           )
  end
end
