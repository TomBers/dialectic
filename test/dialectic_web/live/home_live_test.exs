defmodule DialecticWeb.HomeLiveTest do
  use DialecticWeb.ConnCase, async: true

  alias Dialectic.Accounts
  alias Dialectic.DbActions.Graphs
  import Dialectic.GraphFixtures
  import Dialectic.AccountsFixtures
  import Phoenix.LiveViewTest

  test "does not load Google Analytics in the initial document", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/")

    refute html =~ "googletagmanager.com/gtag"
    assert html =~ "/assets/app.js"
  end

  test "publishes organization and free product structured data", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/")

    json_ld =
      html
      |> LazyHTML.from_fragment()
      |> LazyHTML.filter(~s(script[type="application/ld+json"]))
      |> LazyHTML.text()
      |> Jason.decode!()

    assert json_ld["@context"] == "https://schema.org"

    organization = Enum.find(json_ld["@graph"], &(Map.get(&1, "@type") == "Organization"))

    product =
      Enum.find(json_ld["@graph"], fn entity ->
        "Product" in List.wrap(Map.get(entity, "@type"))
      end)

    faq_page = Enum.find(json_ld["@graph"], &(Map.get(&1, "@type") == "FAQPage"))

    assert organization["name"] == "RationalGrid"
    assert organization["url"] == DialecticWeb.Endpoint.url()
    assert product["name"] == "RationalGrid"
    assert product["isAccessibleForFree"] == true
    assert product["offers"]["price"] == "0.00"
    assert product["offers"]["priceCurrency"] == "USD"
    assert length(faq_page["mainEntity"]) == 3

    assert Enum.any?(faq_page["mainEntity"], fn question ->
             question["name"] == "What are the AI usage limits?" and
               question["acceptedAnswer"]["text"] =~ "three AI requests in progress" and
               question["acceptedAnswer"]["text"] =~ "ten AI requests per minute"
           end)
  end

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

  test "opens existing grids in the reader view", %{conn: conn} do
    graph =
      insert_graph(%{
        title: "Existing Reader Grid #{System.unique_integer([:positive])}"
      })

    {:ok, view, _html} = live(conn, ~p"/")
    render_submit(view, "reply-and-answer", %{"vertex" => %{"content" => graph.title}})

    assert_redirect(view, ~p"/g/#{graph.slug}")
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

    assert has_element?(view, "#home-hero-logo")
    assert has_element?(view, "#home-hero-brand", "RationalGrid")
    assert has_element?(view, "#home-hero-tagline", "See what you think.")

    assert has_element?(
             view,
             "#home-hero-subheading",
             "Know what you think—and show how you got there."
           )

    assert has_element?(view, "#home-video-hero", "Explore a question")
    assert has_element?(view, ~s(#home-sign-up-link[href="/users/register"]), "Sign up free")
    refute has_element?(view, "#home-video-hero video")

    assert has_element?(
             view,
             ~s(#home-hero-background[src*="fractal-branching-tree"][srcset][sizes="100vw"])
           )

    assert has_element?(view, ~s(#home-about-link[href="/about"]), "Why RationalGrid?")

    assert has_element?(
             view,
             ~s(#home-ai-scepticism-link[href="/intro/ai"]),
             "Sceptical about AI?"
           )

    assert has_element?(view, "#home-ai-scepticism-link", "where it can go wrong")
    refute has_element?(view, "#home-public-grid-note")
    refute has_element?(view, "#home-value-summary")
  end

  test "shows a start-grid hero action instead of signup when signed in", %{conn: conn} do
    user = user_fixture()

    {:ok, view, _html} =
      conn
      |> log_in_user(user)
      |> live(~p"/")

    assert has_element?(view, ~s(#home-start-grid-link[href="#start-here"]), "Start a grid")
    refute has_element?(view, "#home-sign-up-link")
  end

  test "shows the product briefly and links to the detailed pages", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#home-learning-loop", "Explore. Keep. Reconsider.")
    assert has_element?(view, "#home-learning-loop", "Questions branch into answers")

    assert has_element?(
             view,
             "#home-chat-distinction",
             "instead of leaving it in another disappearing chat"
           )

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

    assert has_element?(view, "#home-example-video[phx-hook='YouTubeFacade']")
    assert has_element?(view, "#home-example-video-play")

    assert has_element?(
             view,
             ~s(#home-example-video img[src*="rationalgrid-video-preview-768"][srcset][sizes])
           )

    refute has_element?(view, "#home-example-video iframe")
    assert has_element?(view, "#popular-grids", "See what other people explored.")

    assert has_element?(view, "#home-testimonial", "An amazing free specialised AI tool")
    assert has_element?(view, "#home-testimonial", "Philosophy for All and RationalGrid adviser")

    assert has_element?(view, "#home-definition h2", "What is RationalGrid?")

    assert has_element?(view, "#home-ai-limits-faq h2", "AI and source limits")
    assert has_element?(view, "#home-faq-cost", "How much does RationalGrid cost?")
    assert has_element?(view, "#home-faq-ai-usage-limits", "What are the AI usage limits?")
    assert has_element?(view, "#home-faq-ai-usage-limits", "three AI requests in progress")
    assert has_element?(view, "#home-faq-sources", "How does RationalGrid use sources?")

    assert has_element?(
             view,
             ~s(#home-ai-limits-details-link[href="/intro/ai"]),
             "Learn how AI and sources work"
           )

    assert has_element?(
             view,
             "#home-definition",
             "RationalGrid is a free, non-profit, AI-assisted research and argument-mapping tool."
           )

    assert has_element?(
             view,
             "#home-definition",
             "It helps students and researchers organize claims and evidence into structured, shareable formats."
           )

    assert has_element?(
             view,
             "footer p.text-slate-400",
             "See what you think."
           )
  end

  test "explains each answer depth in the start form", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    view
    |> form("#new-idea-form", vertex: %{content: "Why do habits persist?"})
    |> render_submit()

    refute has_element?(view, "#new-idea-mode-simple")
    assert has_element?(view, "#new-idea-mode-high_school", "Plain language")
    assert has_element?(view, "#new-idea-mode-high_school", "Simple")
    assert has_element?(view, "#new-idea-mode-university", "wider context")
    assert has_element?(view, "#new-idea-mode-university", "Expanded")
    assert has_element?(view, "#new-idea-mode-expert", "In-depth")
    assert has_element?(view, "#new-idea-mode-expert", "Rigorous analysis")
    assert has_element?(view, "#new-idea-level-step #home-public-grid-note")
    assert has_element?(view, "#home-public-grid-note", "public and editable by default")
    assert has_element?(view, "#new-idea-mode-university[data-requires-login='true']")
    assert has_element?(view, "#new-idea-mode-expert[data-requires-login='true']")

    view
    |> element("#new-idea-mode-university")
    |> render_click()

    assert has_element?(view, "#answer-level-login-modal", "Unlock deeper answer levels")
    assert has_element?(view, "#answer-level-login-modal", "Sign in to create grids")
  end

  test "prompts signed-out users when a restricted mode is submitted directly", %{conn: conn} do
    answer = "Restricted Home Grid #{System.unique_integer([:positive])}"
    {:ok, view, _html} = live(conn, ~p"/")

    render_submit(view, "reply-and-answer", %{
      "vertex" => %{"content" => answer},
      "mode" => "expert"
    })

    assert has_element?(view, "#answer-level-login-modal", "Unlock deeper answer levels")
    assert is_nil(Graphs.get_graph_by_title(answer))
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
