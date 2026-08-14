defmodule DialecticWeb.SearchLiveTest do
  use DialecticWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Dialectic.GraphFixtures

  test "renders the global search entry point", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/search")

    assert has_element?(view, "#global-search-form")
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
