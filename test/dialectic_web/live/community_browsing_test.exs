defmodule DialecticWeb.CommunityBrowsingTest do
  use DialecticWeb.ConnCase, async: true

  import Dialectic.GraphFixtures
  import Phoenix.LiveViewTest

  alias Dialectic.DbActions.Graphs
  alias Dialectic.Repo

  test "defaults to curated grids and presents the collections in browsing order", %{conn: conn} do
    curated = graph("A curated question", ["Sociology"])
    partner = graph("A partner question", ["Biology"])
    other = graph("An ordinary question", ["Philosophy"])
    private = graph("A private curated question", ["Sociology"], %{is_public: false})

    for grid <- [curated, private] do
      {:ok, _} =
        Graphs.add_curated_grid(%{graph_title: grid.title, section: "curated", position: 0})
    end

    {:ok, _} =
      Graphs.add_curated_grid(%{graph_title: partner.title, section: "featured", position: 0})

    {:ok, view, _} = live(conn, ~p"/community")

    assert has_element?(view, ~s(#community-format-curated[aria-current="page"]))
    assert has_element?(view, "#community-grid-#{curated.slug}")
    refute has_element?(view, "#community-grid-#{partner.slug}")
    refute has_element?(view, "#community-grid-#{other.slug}")
    refute has_element?(view, "#community-grid-#{private.slug}")

    for {category, label, position} <- [
          {"curated", "Curated grids", 1},
          {"all", "All grids", 2},
          {"partners", "Partner grids", 3}
        ] do
      assert has_element?(
               view,
               "#community-format-filters > #community-format-#{category}:nth-child(#{position})",
               label
             )
    end

    refute has_element?(view, "#community-format-filters > a:nth-child(4)")
    assert has_element?(view, ~s(#community-size-input option[value="all"][selected]))

    render_patch(view, ~p"/community?category=curated")
    assert has_element?(view, ~s(#community-format-curated[aria-current="page"]))
    assert has_element?(view, "#community-grid-#{curated.slug}")
    refute has_element?(view, "#community-grid-#{partner.slug}")
    refute has_element?(view, "#community-grid-#{other.slug}")

    render_patch(view, ~p"/community?category=partners")
    assert has_element?(view, "#community-grid-#{partner.slug}")
    refute has_element?(view, "#community-grid-#{curated.slug}")

    assert has_element?(view, ~s(#community-format-all[href="/community?category=all"]))
    render_patch(view, ~p"/community?category=all")
    assert has_element?(view, ~s(#community-format-all[aria-current="page"]))

    for grid <- [curated, partner, other],
        do: assert(has_element?(view, "#community-grid-#{grid.slug}"))

    refute has_element?(view, "#community-grid-#{private.slug}")
  end

  test "searching from the default view reaches grids outside the curated collection", %{
    conn: conn
  } do
    grid = graph("A question outside the selection", ["Sociology"])
    {:ok, view, _} = live(conn, ~p"/community")
    refute has_element?(view, "#community-grid-#{grid.slug}")

    view |> form("#community-search-form", %{search: grid.title}) |> render_change()
    assert has_element?(view, ~s(#community-format-all[aria-current="page"]))
    assert has_element?(view, "#community-grid-#{grid.slug}")
  end

  test "curated and all-grid directories have distinct indexable canonical URLs", %{conn: conn} do
    for {path, canonical_path} <- [
          {~p"/community", ~p"/community"},
          {~p"/community?category=curated", ~p"/community"},
          {~p"/community?category=all", ~p"/community?category=all"}
        ] do
      doc = conn |> get(path) |> html_response(200) |> LazyHTML.from_document()

      assert doc |> LazyHTML.query("link[rel=canonical]") |> LazyHTML.attribute("href") == [
               DialecticWeb.Endpoint.url() <> canonical_path
             ]

      assert doc |> LazyHTML.query("meta[name=robots]") |> LazyHTML.attribute("content") == []
    end
  end

  test "all public grids are browsable across stable pages, including small grids", %{conn: conn} do
    graphs =
      for index <- 1..14,
          do: graph("Grid #{String.pad_leading(to_string(index), 2, "0")}", ["Sociology"])

    private = graph("Private grid", ["Sociology"], %{is_public: false})
    draft = graph("Draft grid", ["Sociology"], %{is_published: false})
    deleted = graph("Deleted grid", ["Sociology"], %{is_deleted: true})

    {:ok, view, _} = live(conn, ~p"/community?tag=sociology")

    assert has_element?(view, "#community-result-count", "1–12 of 14 grids")
    assert has_element?(view, "#community-grid-list > article:nth-of-type(12)")
    refute has_element?(view, "#community-grid-list > article:nth-of-type(13)")

    for hidden <- [private, draft, deleted] do
      refute has_element?(view, "#community-grid-#{hidden.slug}")
    end

    next_path =
      view
      |> element("#community-next-page")
      |> render()
      |> LazyHTML.from_fragment()
      |> LazyHTML.query("a")
      |> LazyHTML.attribute("href")
      |> hd()

    assert URI.decode_query(URI.parse(next_path).query) == %{"tag" => "sociology", "page" => "2"}

    render_patch(view, next_path)
    assert has_element?(view, "#community-result-count", "13–14 of 14 grids")
    assert has_element?(view, "#community-previous-page")
    refute has_element?(view, "#community-next-page")
    assert has_element?(view, "#community-grid-#{List.last(graphs).slug}")

    doc = conn |> get(next_path) |> html_response(200) |> LazyHTML.from_document()

    assert doc |> LazyHTML.query("link[rel=canonical]") |> LazyHTML.attribute("href") == [
             DialecticWeb.Endpoint.url() <> next_path
           ]

    assert doc |> LazyHTML.query("meta[name=robots]") |> LazyHTML.attribute("content") == []
  end

  test "search, topic, collection and size filters combine and survive pagination", %{conn: conn} do
    selected = for index <- 1..13, do: graph("Learning #{index}", ["Sociology"])
    wrong_topic = graph("Learning elsewhere", ["Biology"])
    wrong_title = graph("Unrelated question", ["Sociology"])
    wrong_collection = graph("Learning outside the collection", ["Sociology"])
    wrong_size = sized_graph("Learning in depth", 21)

    for grid <- selected ++ [wrong_topic, wrong_title, wrong_size] do
      {:ok, _} =
        Graphs.add_curated_grid(%{graph_title: grid.title, section: "curated", position: 0})
    end

    {:ok, view, _} = live(conn, ~p"/community?tag=sociology&category=curated&size=small&page=2")
    view |> form("#community-search-form", %{search: "Learning"}) |> render_change()

    assert has_element?(view, "#community-result-count", "1–12 of 13 grids")
    assert has_element?(view, ~s(#community-format-curated[aria-current="page"]))
    assert has_element?(view, ~s(#community-size-input option[value="small"][selected]))

    for grid <- [wrong_topic, wrong_title, wrong_collection, wrong_size],
        do: refute(has_element?(view, "#community-grid-#{grid.slug}"))

    next_path =
      view
      |> element("#community-next-page")
      |> render()
      |> LazyHTML.from_fragment()
      |> LazyHTML.query("a")
      |> LazyHTML.attribute("href")
      |> hd()

    assert URI.decode_query(URI.parse(next_path).query) == %{
             "tag" => "sociology",
             "category" => "curated",
             "size" => "small",
             "search" => "Learning",
             "page" => "2"
           }

    render_patch(view, next_path)
    assert has_element?(view, "#community-result-count", "13–13 of 13 grids")

    view |> form("#community-size-form", %{size: "all"}) |> render_change()
    assert has_element?(view, "#community-result-count", "1–12 of 14 grids")
    assert has_element?(view, ~s(#community-format-curated[aria-current="page"]))
    assert has_element?(view, "#community-clear-topic", "Sociology")
  end

  test "size stays selected across collections and can be cleared independently", %{conn: conn} do
    curated_small = sized_graph("Learning in a curated grid", 4)
    curated_medium = sized_graph("Learning in a medium grid", 5)
    partner_small = sized_graph("Learning in a small partner grid", 4)
    partner_large = sized_graph("Learning in a large partner grid", 21)

    for {section, grids} <- [
          {"curated", [curated_small, curated_medium]},
          {"featured", [partner_small, partner_large]}
        ],
        grid <- grids do
      {:ok, _} =
        Graphs.add_curated_grid(%{graph_title: grid.title, section: section, position: 0})
    end

    {:ok, view, _} =
      live(conn, ~p"/community?category=curated&tag=sociology&search=Learning&sort=updated")

    view |> form("#community-size-form", %{size: "small"}) |> render_change()

    assert has_element?(view, "#community-grid-#{curated_small.slug}")
    refute has_element?(view, "#community-grid-#{curated_medium.slug}")
    refute has_element?(view, "#community-grid-#{partner_small.slug}")

    partner_path =
      view
      |> element("#community-format-partners")
      |> render()
      |> LazyHTML.from_fragment()
      |> LazyHTML.query("a")
      |> LazyHTML.attribute("href")
      |> hd()

    assert URI.decode_query(URI.parse(partner_path).query) == %{
             "category" => "partners",
             "tag" => "sociology",
             "search" => "Learning",
             "sort" => "updated",
             "size" => "small"
           }

    render_patch(view, partner_path)
    assert has_element?(view, "#community-grid-#{partner_small.slug}")
    refute has_element?(view, "#community-grid-#{partner_large.slug}")
    refute has_element?(view, "#community-grid-#{curated_small.slug}")

    view |> form("#community-size-form", %{size: "large"}) |> render_change()
    assert has_element?(view, "#community-grid-#{partner_large.slug}")
    refute has_element?(view, "#community-grid-#{partner_small.slug}")

    view |> form("#community-size-form", %{size: "all"}) |> render_change()
    assert has_element?(view, "#community-grid-#{partner_small.slug}")
    assert has_element?(view, "#community-grid-#{partner_large.slug}")
    refute has_element?(view, "#community-grid-#{curated_small.slug}")
    assert has_element?(view, ~s(#community-format-partners[aria-current="page"]))
    assert has_element?(view, ~s(#community-sort-input option[value="updated"][selected]))
    assert has_element?(view, "#community-clear-topic", "Sociology")
  end

  test "size ranges cover all idea counts without counting compound groups" do
    grids =
      for count <- [0, 4, 5, 20, 21],
          into: %{},
          do: {count, sized_graph("Grid with #{count} ideas", count)}

    for {size, counts} <- [{"small", [0, 4]}, {"medium", [5, 20]}, {"large", [21]}] do
      result = Graphs.browse_public_graphs(size: size)
      assert result.total_count == length(counts)
      assert MapSet.new(result.entries, & &1.graph.slug) == MapSet.new(counts, &grids[&1].slug)
    end
  end

  test "legacy size links still select the matching size on all grids", %{conn: conn} do
    small = sized_graph("Small existing link", 4)
    large = sized_graph("Large existing link", 21)

    for {category, size, included, excluded} <- [
          {"seedlings", "small", small, large},
          {"deep_dives", "large", large, small}
        ] do
      {:ok, view, _} = live(conn, ~p"/community?category=#{category}")
      assert has_element?(view, ~s(#community-format-all[aria-current="page"]))
      assert has_element?(view, ~s(#community-size-input option[value="#{size}"][selected]))
      assert has_element?(view, "#community-grid-#{included.slug}")
      refute has_element?(view, "#community-grid-#{excluded.slug}")
    end
  end

  test "topics can be searched without changing grid results", %{conn: conn} do
    sociology = graph("Social questions", ["Sociology"])
    biology = graph("Biological questions", ["Biology"])

    for grid <- [sociology, biology] do
      {:ok, _} =
        Graphs.add_curated_grid(%{graph_title: grid.title, section: "curated", position: 0})
    end

    {:ok, view, _} = live(conn, ~p"/community")

    view |> form("#community-topic-search-form", %{topic_filter: "SOC"}) |> render_change()
    assert has_element?(view, ~s(#community-topics a[href="/community?tag=sociology"]))
    refute has_element?(view, ~s(#community-topics a[href="/community?tag=biology"]))
    assert has_element?(view, "#community-grid-#{sociology.slug}")
    assert has_element?(view, "#community-result-count", "2 grids")

    view
    |> form("#community-topic-search-form", %{topic_filter: "no such topic"})
    |> render_change()

    assert has_element?(view, "#community-no-topics")

    view |> form("#community-topic-search-form", %{topic_filter: ""}) |> render_change()
    assert has_element?(view, ~s(#community-topics a[href="/community?tag=biology"]))
  end

  test "sorting ranks results and keeps the active topic", %{conn: conn} do
    small = graph("Small grid", ["Sociology"])

    large =
      graph("Large grid", ["Sociology"], %{
        data: %{"nodes" => Enum.map(1..25, &%{"id" => to_string(&1)}), "edges" => []}
      })

    {:ok, view, _} = live(conn, ~p"/community?tag=sociology")

    view |> form("#community-sort-form", %{sort: "largest"}) |> render_change()
    assert has_element?(view, "#community-grid-list > #community-grid-#{large.slug}:first-child")
    assert has_element?(view, "#community-clear-topic", "Sociology")

    render_patch(view, ~p"/community?tag=sociology&category=deep_dives")
    assert has_element?(view, "#community-grid-#{large.slug}")
    refute has_element?(view, "#community-grid-#{small.slug}")
  end

  test "search matches tags and treats wildcard characters literally", %{conn: conn} do
    graph = graph("A question about people", ["Sociology"])
    {:ok, view, _} = live(conn, ~p"/community?search=sociology")
    assert has_element?(view, "#community-grid-#{graph.slug}")
    view |> form("#community-search-form", %{search: "%"}) |> render_change()
    assert has_element?(view, "#community-empty-results")
  end

  test "invalid and out-of-range pages are handled without losing the filters", %{conn: conn} do
    grid = graph("A topic question", ["Sociology"])

    for page <- ["invalid", "-1", "999999999999999999999"] do
      {:ok, view, _} = live(conn, ~p"/community?tag=sociology&page=#{page}")
      assert has_element?(view, "#community-grid-#{grid.slug}")
      assert has_element?(view, "#community-result-count", "1 grid")
    end
  end

  test "browsing returns card fields without loading graph content" do
    graph("Summary grid", ["Sociology"])
    assert %{entries: [%{graph: summary}], total_count: 1} = Graphs.browse_public_graphs()
    refute Map.has_key?(summary, :data)
    assert summary.node_count == 1
  end

  defp graph(title, tags, attrs \\ %{}) do
    insert_graph(Map.merge(%{title: title}, attrs))
    |> Ecto.Changeset.change(tags: tags, inserted_at: ~U[2026-01-01 12:00:00Z])
    |> Repo.update!()
  end

  defp sized_graph(title, count) do
    nodes = for index <- 1..count//1, do: %{"id" => to_string(index)}
    group = %{"id" => "group", "compound" => true}
    graph(title, ["Sociology"], %{data: %{"nodes" => nodes ++ [group], "edges" => []}})
  end
end
