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
    assert has_element?(view, "#popular-grids", "Build on good thinking.")
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
    assert has_element?(view, "#popular-grids", "Curated grids")
    assert has_element?(view, "#home-curated-grids-list")
    assert has_element?(view, ~s(#home-curated-grids-list [data-role="curated-grid-card"]))
    assert has_element?(view, "#home-curated-grids-list > :nth-child(3)")
    refute has_element?(view, "#home-curated-grids-list > :nth-child(4)")
    refute has_element?(view, ~s(#home-curated-grids-list [data-role="grid-card-badge"]))
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
             "Browse community"
           )
  end

  test "renders the profile promotion section for visitors", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#home-profile-section")

    assert has_element?(
             view,
             "#home-profile-section",
             "Share ideas people can build on."
           )

    assert has_element?(
             view,
             ~s(#home-profile-section a[href="/users/register"]),
             "Create your profile"
           )
  end

  test "renders a minimal start section", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#start-here h2", "Ask your first question.")
    assert has_element?(view, "#home-start-panel #new-idea-form")
    refute has_element?(view, "#home-start-steps")
    refute has_element?(view, "#start-here", "Step 1 of 2")
    refute has_element?(view, ~s(#start-here a[href="/intro/how"]))
  end

  test "renders a focused benefit-led hero", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(
             view,
             "#home-hero-title",
             "Explore with AI. Remember what you learn."
           )

    assert has_element?(view, "#home-video-hero", "notes, highlights, and saved paths")
    assert has_element?(view, "#home-video-hero", "Map your first question")

    assert has_element?(
             view,
             ~s(#home-video-hero a[href="#popular-grids"]),
             "Browse curated grids"
           )

    assert has_element?(
             view,
             ~s(#home-ai-scepticism-link[href="/intro/ai"]),
             "Sceptical about AI?"
           )

    assert has_element?(view, "#home-ai-scepticism-link", "where it can go wrong")
    refute has_element?(view, "#home-value-summary")
  end

  test "separates tools for exploration from tools for recall", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#home-exploration-tools", "Explore without losing the thread.")
    assert has_element?(view, "#home-exploration-tools #home-feature-focused-inquiry")
    assert has_element?(view, "#home-exploration-tools #home-feature-levels")
    assert has_element?(view, "#home-exploration-tools #home-feature-critical-thinking")

    assert has_element?(
             view,
             "#home-exploration-tools #home-feature-nonlinear-exploration"
           )

    assert has_element?(view, "#home-recall-tools", "Return without starting again.")
    assert has_element?(view, "#home-recall-tools #home-feature-highlights")
    assert has_element?(view, "#home-recall-tools #home-feature-stars")
    assert has_element?(view, "#home-recall-tools #home-feature-export")
    assert has_element?(view, "#home-recall-tools #home-feature-shared-record")

    assert has_element?(view, "#home-learning-loop", "Learning needs both.")
    assert has_element?(view, "#home-learning-explore", "branch from any word or passage")
    assert has_element?(view, "#home-learning-recall", "star useful ideas")
    assert has_element?(view, "#home-learning-bridge", "every question and note stays in place")

    assert has_element?(
             view,
             ~s(#home-ai-exploration-link[href="/intro/ai"]),
             "Why use AI for exploration?"
           )
  end

  test "shows practical tools for different audiences and shared work", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(
             view,
             "#home-feature-levels",
             "Simple, High School, University, or Expert"
           )

    assert has_element?(view, "#home-feature-nonlinear-exploration", "Explore in any direction")
    assert has_element?(view, "#home-feature-nonlinear-exploration", "one long page of text")
    assert has_element?(view, "#home-feature-export", "Download the grid for your notes")
    assert has_element?(view, "#home-feature-shared-record", "see who added each part")
    assert has_element?(view, "#home-feature-shared-record", "Activity")
    assert has_element?(view, "#home-feature-highlights", "Each gets its own link")
    assert has_element?(view, "#home-feature-stars", "easy to find")
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
