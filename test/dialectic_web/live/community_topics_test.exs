defmodule DialecticWeb.CommunityTopicsTest do
  use DialecticWeb.ConnCase, async: true

  import Dialectic.GraphFixtures
  import Phoenix.LiveViewTest

  alias Dialectic.Repo

  test "topic pages render canonical metadata and public content in the initial response", %{
    conn: conn
  } do
    graph = tagged_graph("Public sociology", ["Sociology"])
    hidden = tagged_graph("Private sociology", ["Sociology"], %{is_public: false})
    canonical = DialecticWeb.Endpoint.url() <> ~p"/community?tag=sociology"

    for tag <- ["Sociology", "sociology", " SOCIOLOGY "] do
      document =
        conn |> get(~p"/community?tag=#{tag}") |> html_response(200) |> LazyHTML.from_document()

      assert attribute(document, "link[rel=canonical]", "href") == [canonical]
      assert attribute(document, "meta[property='og:url']", "content") == [canonical]
      assert attribute(document, "meta[name=robots]", "content") == []

      assert attribute(document, "meta[name=description]", "content") == [
               "Explore public grids about Sociology. Follow questions, compare perspectives, and examine sources shared by the RationalGrid community."
             ]

      assert document |> LazyHTML.query("title") |> LazyHTML.text() =~ "Sociology"

      assert attribute(document, "#community-grid-#{graph.slug}", "id") == [
               "community-grid-#{graph.slug}"
             ]

      assert attribute(document, "#community-grid-#{hidden.slug}", "id") == []
      assert attribute(document, "#main-content", "id") == ["main-content"]
    end
  end

  test "unknown topics and topics used only by unavailable grids are noindex", %{conn: conn} do
    tagged_graph("Private topic grid", ["PrivateOnly"], %{is_public: false})
    tagged_graph("Draft topic grid", ["DraftOnly"], %{is_published: false})
    tagged_graph("Deleted topic grid", ["DeletedOnly"], %{is_deleted: true})

    for tag <- ["Unknown", "PrivateOnly", "DraftOnly", "DeletedOnly"] do
      document =
        conn |> get(~p"/community?tag=#{tag}") |> html_response(200) |> LazyHTML.from_document()

      assert attribute(document, "meta[name=robots]", "content") == ["noindex, nofollow"]
      assert attribute(document, "#community-empty-results", "id") == ["community-empty-results"]
      assert attribute(document, "#community-grid-list article", "id") == []
    end
  end

  test "empty tag values canonicalize to the community page", %{conn: conn} do
    document =
      conn |> get(~p"/community?tag=#{"  "}") |> html_response(200) |> LazyHTML.from_document()

    assert attribute(document, "link[rel=canonical]", "href") == [
             DialecticWeb.Endpoint.url() <> "/community"
           ]

    assert attribute(document, "meta[name=robots]", "content") == []
  end

  test "search and size variants remain noindex", %{conn: conn} do
    tagged_graph("Search sociology", ["Sociology"])

    for path <- [
          ~p"/community?search=sociology",
          ~p"/community?category=deep_dives",
          ~p"/community?size=small",
          ~p"/community?size=medium",
          ~p"/community?size=large",
          ~p"/community?category=curated&size=small",
          ~p"/community?tag=sociology&size=small",
          ~p"/community?tag=sociology&search=example"
        ] do
      document = conn |> get(path) |> html_response(200) |> LazyHTML.from_document()
      assert attribute(document, "meta[name=robots]", "content") == ["noindex, nofollow"]
    end
  end

  test "topic navigation includes all public topics with canonical links", %{conn: conn} do
    tags = Enum.map(1..35, &"Topic #{&1}")
    tagged_graph("Many topics", tags ++ [" SOCIOLOGY ", "sociology", " "])

    {:ok, view, _html} = live(conn, ~p"/community")

    for tag <- tags do
      path = ~p"/community?tag=#{String.downcase(tag)}"
      assert has_element?(view, ~s(#community-topics a[href="#{path}"]))
    end

    assert has_element?(view, ~s(#community-topics a[href="/community?tag=sociology"]))
    refute has_element?(view, ~s(#community-topics a[href="/community?tag="]))
  end

  test "topic browsing and search continue to work with normalized tags", %{conn: conn} do
    graph = tagged_graph("Sociology enquiry", [" Sociology "])
    other = tagged_graph("Unrelated enquiry", ["Biology"])

    {:ok, view, _html} = live(conn, ~p"/community?tag=sociology")

    assert has_element?(view, "#community-page-title", "Sociology")
    assert has_element?(view, "#community-topic-description", "Sociology")
    assert has_element?(view, "#community-grid-#{graph.slug}")
    refute has_element?(view, "#community-grid-#{other.slug}")

    view |> form("#community-search-form", %{search: other.title}) |> render_change()

    assert has_element?(view, "#community-empty-results")
    refute has_element?(view, "#community-grid-#{other.slug}")
    assert has_element?(view, "#community-topic-description", "Sociology")

    render_patch(view, ~p"/community?search=#{other.title}")
    assert has_element?(view, "#community-grid-#{other.slug}")
    refute has_element?(view, "#community-topic-description")
  end

  defp tagged_graph(title, tags, attrs \\ %{}) do
    insert_graph(Map.merge(%{title: title}, attrs))
    |> Ecto.Changeset.change(tags: tags)
    |> Repo.update!()
  end

  defp attribute(document, selector, name) do
    document |> LazyHTML.query(selector) |> LazyHTML.attribute(name)
  end
end
