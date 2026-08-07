defmodule DialecticWeb.HomeLiveTest do
  use DialecticWeb.ConnCase, async: true

  alias Dialectic.Accounts
  alias Dialectic.DbActions.Graphs
  import Dialectic.GraphFixtures
  import Dialectic.AccountsFixtures
  import Phoenix.LiveViewTest

  test "ignores graph search and filter parameters", %{conn: conn} do
    unique = System.unique_integer([:positive])

    curated_graph =
      insert_graph(%{
        title: "Always Visible Curated Grid #{unique}",
        slug: "always-visible-curated-grid-#{unique}"
      })

    {:ok, _curated_grid} =
      Graphs.add_curated_grid(%{
        graph_title: curated_graph.title,
        section: "curated",
        position: 0
      })

    {:ok, view, _html} =
      live(conn, ~p"/?search=missing&tag=unrelated&category=deep_dives")

    assert has_element?(view, "#popular-grids")
    assert has_element?(view, "#home-curated-#{curated_graph.slug}")
    assert has_element?(view, "#popular-grids", "Read a grid before you make one.")
    refute has_element?(view, ~s(#popular-grids input[name="search"]))
    refute has_element?(view, ~s(#popular-grids a[href*="tag="]))
    refute has_element?(view, ~s(#popular-grids a[href*="category="]))
    refute has_element?(view, "#popular-grids", "Results for")
  end

  test "renders three curated grids without partner grids", %{conn: conn} do
    unique = System.unique_integer([:positive])

    graphs =
      for position <- 0..3 do
        graph =
          insert_graph(%{
            title: "Curated Grid #{unique} #{position}",
            slug: "curated-grid-#{unique}-#{position}"
          })

        {:ok, _curated_grid} =
          Graphs.add_curated_grid(%{
            graph_title: graph.title,
            section: "curated",
            position: position
          })

        graph
      end

    partner_graph =
      insert_graph(%{
        title: "Partner Grid #{unique}",
        slug: "partner-grid-#{unique}"
      })

    {:ok, _curated_grid} =
      Graphs.add_curated_grid(%{
        graph_title: partner_graph.title,
        section: "featured",
        position: 0
      })

    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#curated")
    assert has_element?(view, "#curated", "Curated grids")
    assert has_element?(view, "#home-curated-grids-list")
    assert has_element?(view, "#home-curated-grids-list > :nth-child(3)")
    refute has_element?(view, "#home-curated-grids-list > :nth-child(4)")
    refute has_element?(view, "#home-curated-#{partner_graph.slug}")
    refute has_element?(view, "#home-community-grid-list")

    assert Enum.any?(graphs, fn graph ->
             has_element?(view, "#home-curated-#{graph.slug}")
           end)
  end

  test "emphasizes the community grid library action", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(
             view,
             ~s(#home-community-grids-link[href="/community"]),
             "Explore all community grids"
           )
  end

  test "renders the profile promotion section for visitors", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#home-profile-section")

    assert has_element?(
             view,
             "#home-profile-section",
             "Publish a trail others can follow."
           )

    assert has_element?(
             view,
             ~s(#home-profile-section a[href="/users/register"]),
             "Create your profile"
           )
  end

  test "renders a minimal start section", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#start-here h2", "What do you want to understand?")
    assert has_element?(view, "#home-start-panel #new-idea-form")
    refute has_element?(view, "#home-start-steps")
    refute has_element?(view, "#start-here", "Step 1 of 2")
    refute has_element?(view, ~s(#start-here a[href="/intro/how"]))
  end

  test "explains each answer depth in the start form", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    view
    |> form("#new-idea-form", vertex: %{content: "Why do habits persist?"})
    |> render_submit()

    assert has_element?(view, "#new-idea-mode-simple", "Plain language, everyday examples")
    assert has_element?(view, "#new-idea-mode-high_school", "Clear concepts")
    assert has_element?(view, "#new-idea-mode-university", "More precise terminology")
    assert has_element?(view, "#new-idea-mode-expert", "Technical terms")
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
