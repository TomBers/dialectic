defmodule DialecticWeb.SearchLiveTest do
  use DialecticWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Dialectic.GraphFixtures

  test "search supports questions, pagination, and resetting the result stream", %{conn: conn} do
    for index <- 1..14 do
      GraphFixtures.insert_graph(%{
        title: "Free will example #{index}",
        slug: "free-will-#{index}"
      })
    end

    {:ok, view, _html} = live(conn, ~p"/search")
    view |> form("#global-search-form", %{"q" => "Does free will exist?"}) |> render_change()

    assert has_element?(view, "#global-search-items article", "Free will")
    assert has_element?(view, "#global-search-next")
    refute has_element?(view, "#global-search-previous")

    view |> element("#global-search-next") |> render_click()
    assert has_element?(view, "#global-search-previous")
    refute has_element?(view, "#global-search-next")
    assert has_element?(view, "#global-search-items > article:nth-child(2)")
    refute has_element?(view, "#global-search-items > article:nth-child(3)")

    view |> form("#global-search-form", %{"q" => "nonexistent topic"}) |> render_change()
    assert has_element?(view, "#global-search-empty")
    refute has_element?(view, "#global-search-pagination")

    view |> form("#global-search-form", %{"q" => "free will"}) |> render_change()
    assert has_element?(view, "#global-search-next")
    refute has_element?(view, "#global-search-previous")
  end

  test "renders the global search entry point", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/search")

    assert has_element?(view, "#global-search-form")
    assert has_element?(view, "label[for='global-search-input']")
    assert has_element?(view, "#global-search-prompt")
  end

  test "shows matching node content with a reader link", %{conn: conn} do
    term = "searchable-orbit-#{System.unique_integer([:positive])}"
    slug = "searchable-orbit-grid-#{System.unique_integer([:positive])}"

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
          }
        ],
        "edges" => []
      }
    })

    {:ok, view, _html} = live(conn, ~p"/search?q=#{term}")

    assert has_element?(view, "#global-search-result-#{slug}", "A grid with an unrelated title")

    assert has_element?(
             view,
             "#global-search-result-#{slug}-node-7[href='/g/#{slug}?node=7']",
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

    {:ok, view, _html} = live(conn, ~p"/search?q=#{term}")

    assert has_element?(view, "#global-search-empty")
    refute render(view) =~ "Private search result"
  end
end
