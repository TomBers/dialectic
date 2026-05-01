defmodule DialecticWeb.HomeLiveTest do
  use DialecticWeb.ConnCase, async: true

  import Dialectic.GraphFixtures
  import Phoenix.LiveViewTest

  test "renders mobile graph cards alongside the desktop table", %{conn: conn} do
    graph =
      insert_graph(%{
        title: "Mobile Home Grid",
        tags: ["Mobile", "UX", "Design"],
        data: %{
          "nodes" => [
            %{
              "id" => "1",
              "content" => "Start",
              "class" => "origin",
              "deleted" => false,
              "compound" => false
            },
            %{
              "id" => "2",
              "content" => "Question",
              "class" => "question",
              "deleted" => false,
              "compound" => false
            },
            %{
              "id" => "3",
              "content" => "Answer",
              "class" => "answer",
              "deleted" => false,
              "compound" => false
            },
            %{
              "id" => "4",
              "content" => "Detail",
              "class" => "detail",
              "deleted" => false,
              "compound" => false
            }
          ],
          "edges" => [
            %{"data" => %{"id" => "1_2", "source" => "1", "target" => "2"}},
            %{"data" => %{"id" => "2_3", "source" => "2", "target" => "3"}},
            %{"data" => %{"id" => "3_4", "source" => "3", "target" => "4"}}
          ]
        }
      })

    {:ok, view, _html} = live(conn, ~p"/?search=Mobile Home Grid")

    assert has_element?(view, "#home-graph-mobile-list")
    assert has_element?(view, "#home-graph-desktop-table")
    assert has_element?(view, "#home-mobile-graph-#{graph.slug}")
    assert has_element?(view, "#home-mobile-graph-#{graph.slug} a", graph.title)
    assert has_element?(view, "#home-mobile-graph-#{graph.slug} a[aria-label]")
  end
end
