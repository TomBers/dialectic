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

  test "links to the comparison index from the footer", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#home-footer-comparisons-link[href='/compare']")
  end

  test "links to the comparison index from the relevant FAQ answer", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(
             view,
             "#home-faq-chat-assistants > p #home-faq-comparisons-link[href='/compare']"
           )
  end

  test "links to the Notion and Obsidian workflow from the FAQ", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(
             view,
             "#home-faq-notion-obsidian #home-faq-notion-obsidian-link[href='/compare/notion-obsidian']"
           )
  end

  test "publishes organization and free software application structured data", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/")

    json_ld =
      html
      |> LazyHTML.from_fragment()
      |> LazyHTML.filter(~s(script[type="application/ld+json"]))
      |> LazyHTML.text()
      |> Jason.decode!()

    assert json_ld["@context"] == "https://schema.org"

    organization = Enum.find(json_ld["@graph"], &(Map.get(&1, "@type") == "Organization"))

    software_application =
      Enum.find(json_ld["@graph"], fn entity ->
        Map.get(entity, "@type") == "SoftwareApplication"
      end)

    faq_page = Enum.find(json_ld["@graph"], &(Map.get(&1, "@type") == "FAQPage"))

    assert organization["name"] == "RationalGrid"
    assert organization["url"] == DialecticWeb.Endpoint.url()
    assert software_application["name"] == "RationalGrid"
    assert software_application["isAccessibleForFree"] == true
    assert software_application["offers"]["price"] == "0.00"
    assert software_application["offers"]["priceCurrency"] == "USD"

    refute Enum.any?(json_ld["@graph"], fn entity ->
             "Product" in List.wrap(Map.get(entity, "@type"))
           end)

    assert length(faq_page["mainEntity"]) == 5

    assert Enum.any?(faq_page["mainEntity"], fn question ->
             question["name"] == "What are the AI usage limits?" and
               question["acceptedAnswer"]["text"] =~ "three AI requests in progress" and
               question["acceptedAnswer"]["text"] =~ "ten AI requests per minute"
           end)

    assert Enum.any?(faq_page["mainEntity"], fn question ->
             question["name"] == "Can I use RationalGrid with Notion or Obsidian?" and
               question["acceptedAnswer"]["text"] =~ "export the grid as Markdown"
           end)
  end

  test "ignores graph search and filter parameters", %{conn: conn} do
    graph = insert_graph(%{title: "Always visible partner grid"})

    {:ok, _} =
      Graphs.add_curated_grid(%{graph_title: graph.title, section: "featured", position: 0})

    {:ok, view, _html} = live(conn, ~p"/?search=missing&tag=unrelated&category=deep_dives")

    assert has_element?(view, "#home-partner-#{graph.slug}")
    assert has_element?(view, "#popular-grids", "Partner grids")
    refute has_element?(view, ~s(#popular-grids input[name="search"]))
  end

  test "shows the first three partner grids in their curated order", %{conn: conn} do
    partners =
      for position <- 0..3 do
        graph = insert_graph(%{title: "Partner grid #{position}"})

        {:ok, _} =
          Graphs.add_curated_grid(%{
            graph_title: graph.title,
            section: "featured",
            position: position
          })

        graph
      end

    curated = insert_graph(%{title: "Separate curated grid"})

    {:ok, _} =
      Graphs.add_curated_grid(%{graph_title: curated.title, section: "curated", position: 0})

    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#home-partners")
    assert has_element?(view, ~s(#home-partner-grids-list [data-role="partner-grid-card"]))
    refute has_element?(view, "#home-partner-grids-list > :nth-child(4)")
    refute has_element?(view, "#home-partner-#{curated.slug}")
    refute has_element?(view, "#home-partner-#{Enum.at(partners, 3).slug}")

    for {graph, index} <- partners |> Enum.take(3) |> Enum.with_index(1) do
      assert has_element?(
               view,
               "#home-partner-grids-list > #home-partner-#{graph.slug}:nth-child(#{index})"
             )
    end
  end

  test "community grids are easy to reach without signing in", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(
             view,
             ~s(#home-community-secondary-link[href="/community"]),
             "Browse public grids"
           )
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

    refute has_element?(view, "#home-why-understanding")
    refute has_element?(view, "#home-exploration-tools")
    refute has_element?(view, "#home-recall-tools")
    refute has_element?(view, "#home-profile-section")
  end

  test "offers existing public grids in the reader view", %{conn: conn} do
    graph =
      insert_graph(%{
        title: "Existing Reader Grid #{System.unique_integer([:positive])}"
      })

    {:ok, view, _html} = live(conn, ~p"/")
    render_submit(view, "reply-and-answer", %{"vertex" => %{"content" => graph.title}})

    assert has_element?(view, "#existing-grid-choice")
    assert has_element?(view, "#open-existing-grid[href='/g/#{graph.slug}']")
    assert has_element?(view, "#create-separate-grid")

    view |> element("#cancel-existing-grid") |> render_click()
    refute has_element?(view, "#existing-grid-choice")
  end

  test "places one labelled question form in the hero and preserves the start anchor", %{
    conn: conn
  } do
    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#home-video-hero #start-here #new-idea-form")

    assert has_element?(
             view,
             ~s(#home-question-label[for="new-idea-input"]),
             "What are you curious about?"
           )

    assert view |> element("#new-idea-form") |> render()
    assert has_element?(view, ~s(#home-community-secondary-link[href="/community"]))

    assert has_element?(
             view,
             "#home-mobile-community-start",
             "ask follow-up questions from your phone"
           )

    assert has_element?(view, ~s(#home-mobile-community-link[href="/community"]))
    refute has_element?(view, "#home-start-steps")
    refute has_element?(view, "#start-here", "Step 1 of 2")
    refute has_element?(view, ~s(#start-here a[href="/intro/how"]))
  end

  test "renders a focused benefit-led hero", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#home-hero-logo")
    assert has_element?(view, "#home-hero-brand", "RationalGrid")
    assert has_element?(view, "#home-hero-title", "Follow your curiosity. Build on every answer.")

    assert has_element?(
             view,
             "#home-hero-subheading",
             "A grid grows as you ask, keeping the connections visible"
           )

    assert has_element?(view, "#home-video-hero #new-idea-input")
    assert has_element?(view, "#home-video-hero #new-idea-submit")

    assert has_element?(
             view,
             ~s(#home-community-secondary-link[href="/community"]),
             "Browse public grids"
           )

    refute has_element?(view, "#home-example-link")

    assert has_element?(view, "#home-try-reassurance", "without an account")

    assert has_element?(
             view,
             "#home-try-reassurance",
             "Sign up free to save bookmarks and highlights"
           )

    refute has_element?(view, ~s(#home-video-hero a[href="/users/register"]))

    assert has_element?(
             view,
             ~s(#home-final-sign-up-link[href="/users/register"]),
             "Sign up free"
           )

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

  test "keeps trying a question available and links signed-in users to their recall library", %{
    conn: conn
  } do
    user = user_fixture()

    {:ok, view, _html} =
      conn
      |> log_in_user(user)
      |> live(~p"/")

    assert has_element?(view, "#home-video-hero #new-idea-input")
    assert has_element?(view, "#home-video-hero #new-idea-submit")

    assert has_element?(view, ~s(#home-community-secondary-link[href="/community"]))

    username = Dialectic.Accounts.User.effective_username(user)
    library_path = "/u/#{username}#profile-thinking-library"
    assert has_element?(view, ~s(#home-saved-for-recall-link[href="#{library_path}"]))
    assert has_element?(view, ~s(#home-final-library-link[href="#{library_path}"]))
    refute has_element?(view, "#home-try-reassurance")
    refute has_element?(view, "#home-final-sign-up-link")
  end

  test "shows the product briefly and links to the detailed pages", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#home-learning-loop h2", "See the questions connect.")
    assert has_element?(view, "#home-learning-loop", "follow the reasoning again later")

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

    assert has_element?(
             view,
             "#home-testimonial [data-testimonial-attribution]",
             "Alexandra Konoplyanik"
           )

    assert has_element?(
             view,
             "#home-testimonial [data-testimonial-attribution]",
             "RationalGrid adviser"
           )

    assert has_element?(
             view,
             "#home-proof-carousel[phx-hook='ProofCarousel'][phx-update='ignore']"
           )

    assert has_element?(view, "#home-proof-previous")
    assert has_element?(view, "#home-proof-next")

    assert has_element?(
             view,
             ~s(#home-case-study-organization-link[href="https://philosophynow.org/"]),
             "Philosophy Now"
           )

    assert has_element?(
             view,
             ~s(#home-testimonial-organization-link[href="https://pfalondon.org/"]),
             "Philosophy for All"
           )

    assert has_element?(
             view,
             "#home-research-case-study",
             "How Philosophy Now mapped one article into 35 connected ideas."
           )

    assert has_element?(view, "#home-research-case-study", "Ignacio Gonzalez")
    assert has_element?(view, "#home-research-case-study", "psychological susceptibility")

    assert has_element?(
             view,
             ~s(#home-case-study-heading-organization-link[href="https://philosophynow.org/"][target="_blank"]),
             "Philosophy Now"
           )

    assert has_element?(
             view,
             ~s(#home-case-study-grid-link[href*="inspired-by-the-philosophy-now-article"]),
             "Explore the 35-point grid"
           )

    assert has_element?(
             view,
             ~s(#home-case-study-source-link[href*="philosophynow.org/issues/173"]),
             "Read the source article"
           )

    assert has_element?(view, "#home-definition h2", "What is RationalGrid?")

    assert has_element?(view, "#home-ai-limits-faq h2", "AI and source limits")
    assert has_element?(view, "#home-faq-cost", "How much does RationalGrid cost?")
    assert has_element?(view, "#home-faq-ai-usage-limits", "What are the AI usage limits?")
    assert has_element?(view, "#home-faq-ai-usage-limits", "three AI requests in progress")
    assert has_element?(view, "#home-faq-sources", "How does RationalGrid use sources?")

    assert has_element?(
             view,
             "#home-faq-chat-assistants",
             "Why not just use ChatGPT or Claude?"
           )

    assert has_element?(view, "#home-faq-chat-assistants", "when the path matters")

    assert has_element?(
             view,
             ~s(#home-ai-limits-details-link[href="/intro/ai"]),
             "Learn how AI and sources work"
           )

    assert has_element?(
             view,
             "#home-definition",
             "RationalGrid is a free, not-for-profit, AI-assisted research and argument-mapping tool."
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

  test "repeats the invitation after proof and at the bottom while keeping one hero form", %{
    conn: conn
  } do
    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(
             view,
             "#home-video-hero + #home-learning-journey + #home-proof-carousel + #home-product-preview + #popular-grids + #home-definition + #home-ai-limits-faq + #home-final-cta + footer"
           )

    for location <- ["proof", "final"] do
      assert has_element?(
               view,
               "#home-#{location}-start-grid-link[href='#start-here'][aria-controls='new-idea-input'][phx-click]"
             )

      assert has_element?(view, "#home-#{location}-community-link[href='/community']")
      refute has_element?(view, "#home-#{location}-actions form")
    end
  end

  test "explains building a grid through exploration before introducing recall tools", %{
    conn: conn
  } do
    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(
             view,
             "#home-learning-ask + #home-learning-explore + #home-learning-return"
           )

    assert has_element?(view, "#home-learning-explore", "Challenge the answer")
    assert has_element?(view, "#home-learning-explore", "Explain a term")
    assert has_element?(view, "#home-return-tools", "Search")
    assert has_element?(view, "#home-return-tools", "Highlights")
    assert has_element?(view, "#home-return-tools", "Saved for recall")
    assert has_element?(view, "#home-recall-account-note", "free account")
    assert has_element?(view, ~s(#home-grid-preview-link[href="#home-learning-journey"]))

    assert has_element?(
             view,
             ~s(#home-example-question-link[href="/questions/does-ai-make-us-better-thinkers"])
           )

    refute has_element?(view, "#home-saved-for-recall-link")
    refute has_element?(view, "#home-final-library-link")
    assert has_element?(view, ~s(#home-final-sign-up-link[href="/users/register"]))
  end

  test "existing prompt links still prefill the hero form and request focus", %{conn: conn} do
    {:ok, view, _html} =
      live(conn, ~p"/?initial_prompt=Why%20do%20habits%20persist%3F&focus=grid#start-here")

    assert has_element?(
             view,
             "#home-video-hero #new-idea-input[autofocus]",
             "Why do habits persist?"
           )

    view
    |> form("#new-idea-form", vertex: %{content: "Why do habits persist?"})
    |> render_submit()

    assert has_element?(view, "#home-video-hero #new-idea-level-step")
    assert has_element?(view, "#home-public-grid-note", "public and editable by default")
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
