defmodule DialecticWeb.CommunitySearchTest do
  use DialecticWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Dialectic.GraphFixtures
  alias Dialectic.DbActions.Graphs

  test "search supports questions, pagination, and resetting the result stream", %{conn: conn} do
    for index <- 1..14 do
      GraphFixtures.insert_graph(%{
        title: "Free will example #{index}",
        slug: "free-will-#{index}"
      })
    end

    {:ok, view, _html} = live(conn, ~p"/community?category=all")

    view
    |> form("#community-search-form", %{"search" => "Does free will exist?"})
    |> render_change()

    assert has_element?(view, "#community-grid-list article", "Free will")
    refute has_element?(view, "#community-empty-results")
    assert has_element?(view, "#community-next-page")
    assert has_element?(view, "#community-previous-page[disabled]")

    view |> element("#community-next-page") |> render_click()
    assert has_element?(view, "#community-previous-page")
    assert has_element?(view, "#community-next-page[disabled]")
    assert has_element?(view, "#community-grid-list > article:nth-child(2)")
    refute has_element?(view, "#community-grid-list > article:nth-child(3)")

    view |> form("#community-search-form", %{"search" => "nonexistent topic"}) |> render_change()
    assert has_element?(view, "#community-empty-results")
    refute has_element?(view, "#community-grid-list article")
    refute has_element?(view, "#community-pagination")

    view |> form("#community-search-form", %{"search" => "free will"}) |> render_change()
    refute has_element?(view, "#community-empty-results")
    assert has_element?(view, "#community-next-page")
    assert has_element?(view, "#community-previous-page[disabled]")
  end

  test "old search URLs redirect to Community with the query and page", %{conn: conn} do
    conn = get(conn, ~p"/search?q=free%20will&page=2")
    target = redirected_to(conn)
    assert URI.parse(target).path == "/community"

    assert URI.decode_query(URI.parse(target).query) == %{
             "category" => "all",
             "search" => "free will",
             "page" => "2"
           }
  end

  test "shows content and sources with reader links while respecting filters", %{conn: conn} do
    term = "searchable-orbit-#{System.unique_integer([:positive])}"
    slug = "searchable-orbit-grid-#{System.unique_integer([:positive])}"

    graph =
      GraphFixtures.insert_graph(%{
        title: "A grid with an unrelated title",
        slug: slug,
        data: %{
          "nodes" => [
            %{
              "id" => "7",
              "content" => "# Orbital detail\n\nThis answer contains #{term} in context.",
              "source_text" => nil,
              "class" => "answer",
              "user" => "",
              "parent" => nil,
              "noted_by" => [],
              "deleted" => false,
              "compound" => false
            },
            %{
              "id" => "8",
              "content" => "# Background reference",
              "source_text" => "The original source discusses #{term}.",
              "class" => "source",
              "deleted" => false,
              "compound" => false
            }
          ],
          "edges" => []
        }
      })

    {:ok, _} =
      Graphs.add_curated_grid(%{graph_title: graph.title, section: "curated", position: 0})

    GraphFixtures.insert_graph(%{title: "Outside the selected collection #{term}"})

    {:ok, view, _html} =
      live(conn, ~p"/community?category=curated&size=small&sort=updated&search=#{term}")

    assert has_element?(view, "#community-result-count", "1 grid")

    assert has_element?(
             view,
             "#community-grid-#{slug}-node-8[href='/g/#{slug}?node=8']",
             "Source"
           )

    assert has_element?(view, "#community-grid-#{slug}", "A grid with an unrelated title")

    assert has_element?(
             view,
             "#community-grid-#{slug}-node-7[href='/g/#{slug}?node=7']",
             "Orbital detail"
           )
  end

  test "does not render private content", %{conn: conn} do
    term = "concealed-idea-#{System.unique_integer([:positive])}"

    GraphFixtures.insert_graph(%{
      title: "Private search result",
      slug: "private-global-search-#{System.unique_integer([:positive])}",
      is_public: false,
      data: %{
        "nodes" => [
          %{
            "id" => "1",
            "content" => term,
            "class" => "answer",
            "deleted" => false
          }
        ],
        "edges" => []
      }
    })

    {:ok, view, _html} = live(conn, ~p"/community?category=all&search=#{term}")

    assert has_element?(view, "#community-empty-results")
    refute has_element?(view, "#community-grid-list article")
  end
end
