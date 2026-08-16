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
    assert has_element?(view, "#popular-grids", "See what other people explored.")
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

  test "keeps explanatory detail off the homepage and links to About", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(
             view,
             ~s(#home-about-link[href="/about"]),
             "Why RationalGrid?"
           )

    assert has_element?(
             view,
             ~s(#home-features-link[href="/about"]),
             "Explore all features"
           )

    refute has_element?(view, "#home-why-understanding")
    refute has_element?(view, "#home-exploration-tools")
    refute has_element?(view, "#home-recall-tools")
    refute has_element?(view, "#home-profile-section")
  end

  test "renders a minimal start section", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#start-here h2", "Start with a question.")
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
             "For questions that matter, make up your own mind."
           )

    assert has_element?(view, "#home-video-hero", "Explore with AI to discover new information")
    assert has_element?(view, "#home-video-hero", "keep, find, and share what matters")
    assert has_element?(view, "#home-video-hero", "Explore a question")

    assert has_element?(view, ~s(#home-about-link[href="/about"]), "Why RationalGrid?")

    assert has_element?(
             view,
             ~s(#home-ai-scepticism-link[href="/intro/ai"]),
             "Sceptical about AI?"
           )

    assert has_element?(view, "#home-ai-scepticism-link", "where it can go wrong")
    assert has_element?(view, "#home-public-grid-note", "public and editable by default")
    refute has_element?(view, "#home-value-summary")
  end

  test "shows the product briefly and links to the detailed pages", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#home-learning-loop", "Explore. Keep. Reconsider.")

    assert has_element?(
             view,
             ~s(#home-features-link[href="/about"]),
             "Explore all features"
           )

    assert has_element?(
             view,
             ~s(#home-guide-link[href="/intro/how"]),
             "Read the guide"
           )

    assert has_element?(view, "#popular-grids", "See what other people explored.")
  end

  test "explains each answer depth in the start form", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    view
    |> form("#new-idea-form", vertex: %{content: "Why do habits persist?"})
    |> render_submit()

    refute has_element?(view, "#new-idea-mode-simple")
    assert has_element?(view, "#new-idea-mode-high_school", "Clear concepts")
    assert has_element?(view, "#new-idea-mode-high_school", "Standard")
    assert has_element?(view, "#new-idea-mode-university", "More precise terminology")
    assert has_element?(view, "#new-idea-mode-university", "Detailed")
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
