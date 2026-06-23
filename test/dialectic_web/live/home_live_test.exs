defmodule DialecticWeb.HomeLiveTest do
  use DialecticWeb.ConnCase, async: true

  alias Dialectic.Accounts
  alias Dialectic.DbActions.Graphs
  import Dialectic.GraphFixtures
  import Dialectic.AccountsFixtures
  import Phoenix.LiveViewTest

  test "renders graph cards in the main homepage list", %{conn: conn} do
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

    assert has_element?(view, "#popular-grids")
    assert has_element?(view, "#home-graph-card-list")
    assert has_element?(view, "#home-card-graph-#{graph.slug}")
    assert has_element?(view, "#home-card-graph-#{graph.slug} a", graph.title)
    assert has_element?(view, "#home-card-graph-#{graph.slug} a[aria-label]")
    refute has_element?(view, ~s([data-tw-container="Home graph list"]))
  end

  test "renders partner grids as shared cards", %{conn: conn} do
    unique = System.unique_integer([:positive])

    graph =
      insert_graph(%{
        title: "Featured Partner Grid #{unique}",
        slug: "featured-partner-grid-#{unique}"
      })

    {:ok, _curated_grid} =
      Graphs.add_curated_grid(%{
        graph_title: graph.title,
        section: "featured",
        position: 0
      })

    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#curated")
    assert has_element?(view, "#featured-grids-list")
    assert has_element?(view, "#featured-#{graph.slug}")
    assert has_element?(view, "#featured-#{graph.slug} a", graph.title)
    assert has_element?(view, "#featured-#{graph.slug}", "Partner grid")
  end

  test "logged in users see profile entry in the header without a settings link", %{conn: conn} do
    user = user_fixture()
    {:ok, user} = Accounts.update_user_profile(user, %{username: "headerprofile"})

    html =
      conn
      |> log_in_user(user)
      |> get(~p"/")
      |> html_response(200)

    assert html =~ ~s(href="/u/headerprofile")
    assert html =~ "My Profile"
    refute html =~ ~s(href="/users/settings")
  end
end
