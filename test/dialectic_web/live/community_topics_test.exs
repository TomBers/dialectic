defmodule DialecticWeb.CommunityTopicsTest do
  use DialecticWeb.ConnCase, async: true

  import Dialectic.GraphFixtures
  import Phoenix.LiveViewTest

  alias Dialectic.Repo

  test "non-scalar query parameters fall back safely in HTTP and LiveView requests", %{conn: conn} do
    graph = tagged_graph("Malformed query grid", ["Sociology"])

    for key <- ["search", "tag", "category", "size", "sort", "page"],
        query <- ["#{key}[]=x", "#{key}[nested]=x"] do
      path = "/community?" <> query
      document = conn |> get(path) |> html_response(200) |> LazyHTML.from_document()

      assert attribute(document, "link[rel=canonical]", "href") == [
               DialecticWeb.Endpoint.url() <> "/community"
             ]

      {:ok, view, _} = live(conn, path)
      assert has_element?(view, "#community-grid-#{graph.slug}")
      assert has_element?(view, ~s(#community-search-input[value=""]))
      refute has_element?(view, "#community-clear-topic")
    end
  end

  test "malformed parameters do not discard valid filters", %{conn: conn} do
    sociology = tagged_graph("Social questions", ["Sociology"])
    biology = tagged_graph("Biological questions", ["Biology"])

    {:ok, view, _} = live(conn, "/community?tag=sociology&search[]=x")
    assert has_element?(view, "#community-grid-#{sociology.slug}")
    refute has_element?(view, "#community-grid-#{biology.slug}")
    assert has_element?(view, "#community-clear-topic", "Sociology")

    render_patch(view, "/community?tag[nested]=x&search=Biological")
    assert has_element?(view, "#community-grid-#{biology.slug}")
    refute has_element?(view, "#community-grid-#{sociology.slug}")
  end

  test "non-text search event values clear safely", %{conn: conn} do
    grid = tagged_graph("A browsable grid", ["Sociology"])
    {:ok, view, _} = live(conn, "/community?search=missing")

    for value <- [["x"], %{"nested" => "x"}, nil, 7] do
      render_hook(view, "search", %{"search" => value})
      render_hook(view, "filter_topics", %{"topic_filter" => value})
      assert has_element?(view, "#community-grid-#{grid.slug}")
      assert has_element?(view, ~s(#community-topics a[href="/community?tag=sociology"]))
    end
  end

  test "topic browsing loads bounded batches and search can reach topics beyond the first batch",
       %{conn: conn} do
    tags = for index <- 1..120, do: "Topic " <> String.pad_leading(to_string(index), 3, "0")
    grid = tagged_graph("Many browsable topics", tags)
    {:ok, view, _} = live(conn, "/community")

    assert has_element?(view, "#community-topics > a:nth-child(50)")
    refute has_element?(view, "#community-topics > a:nth-child(51)")
    assert has_element?(view, "#community-more-topics")

    view |> element("#community-more-topics") |> render_click()
    assert has_element?(view, "#community-topics > a:nth-child(100)")
    refute has_element?(view, "#community-topics > a:nth-child(101)")

    view |> element("#community-more-topics") |> render_click()
    assert has_element?(view, "#community-topics > a:nth-child(120)")
    refute has_element?(view, "#community-more-topics")

    view |> form("#community-topic-search-form", %{topic_filter: "TOPIC 119"}) |> render_change()
    assert has_element?(view, ~s(#community-topics a[href="/community?tag=topic+119"]))
    refute has_element?(view, "#community-topics > a:nth-child(2)")
    refute has_element?(view, "#community-more-topics")
    assert has_element?(view, "#community-grid-#{grid.slug}")

    view |> form("#community-topic-search-form", %{topic_filter: ""}) |> render_change()
    assert has_element?(view, "#community-topics > a:nth-child(50)")
    refute has_element?(view, "#community-topics > a:nth-child(51)")
    assert has_element?(view, "#community-more-topics")

    render_patch(view, "/community?tag=TOPIC+119")
    assert has_element?(view, "#community-page-title", "Topic 119 grids")
    assert has_element?(view, "#community-grid-#{grid.slug}")
  end

  test "topic search fetches just one bounded batch from the database", %{conn: conn} do
    tagged_graph("Topics for query limits", Enum.map(1..120, &"Topic #{&1}"))
    {:ok, view, _} = live(conn, "/community")
    handler_id = {__MODULE__, make_ref()}

    :ok =
      :telemetry.attach(
        handler_id,
        [:dialectic, :repo, :query],
        fn _event, _measurements, metadata, {test_pid, view_pid} ->
          if self() == view_pid, do: send(test_pid, {:topic_query, metadata.result})
        end,
        {self(), view.pid}
      )

    on_exit(fn -> :telemetry.detach(handler_id) end)

    view |> form("#community-topic-search-form", %{topic_filter: "Topic"}) |> render_change()
    assert_receive {:topic_query, {:ok, %{num_rows: 51}}}
    refute_receive {:topic_query, _}
    assert has_element?(view, "#community-topics > a:nth-child(50)")
    refute has_element?(view, "#community-topics > a:nth-child(51)")
  end

  test "topic searches treat SQL wildcard characters literally", %{conn: conn} do
    tagged_graph("Literal topics", [
      "100%",
      "1000",
      "under_score",
      "underscore",
      "back\\slash",
      "backslash"
    ])

    {:ok, view, _} = live(conn, "/community")

    for {term, label} <- [{"%", "100%"}, {"_", "Under_score"}, {"\\", "Back\\slash"}] do
      view |> form("#community-topic-search-form", %{topic_filter: term}) |> render_change()
      assert has_element?(view, "#community-topics > a", label)
      refute has_element?(view, "#community-topics > a:nth-child(2)")
    end
  end

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
