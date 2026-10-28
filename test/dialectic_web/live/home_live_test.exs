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

  test "links to the comparison index from the visible concerns section", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(
             view,
             "#home-before-you-start #home-concern-chat-assistants #home-concern-comparisons-link[href='/compare']"
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

    assert length(faq_page["mainEntity"]) == 12

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
    assert has_element?(view, "#popular-grids", "Two ways to get started")
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
             ~s(#home-learning-explore #home-community-grids-link[href="/community"]),
             "Explore community grids"
           )
  end

  test "emphasizes the community grid library action", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(
             view,
             ~s(#home-community-grids-link[href="/community"]),
             "Explore community grids"
           )
  end

  test "keeps explanatory detail off the homepage and links to About", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(
             view,
             ~s(#home-footer-about-link[href="/about"]),
             "About"
           )

    refute has_element?(view, "#home-why-understanding")
    refute has_element?(view, "#home-exploration-tools")
    refute has_element?(view, "#home-recall-tools")
    refute has_element?(view, "#home-profile-section")
  end

  test "account creation replaces public grid creation on home", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")
    refute has_element?(view, "#new-idea-form")
    refute has_element?(view, "#existing-grid-choice")

    assert has_element?(
             view,
             "#home-hero-sign-up-link[data-preserve-auth-return='false']",
             "Create a free account"
           )
  end

  test "the hero directs signup to private creation and preserves the start anchor", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(
             view,
             "#home-video-hero #start-here #home-hero-sign-up-link[href='/users/register?return_to=%2Fmy%2Flearning%3Fnew%3Dtrue']"
           )

    refute has_element?(view, "#home-video-hero form")
    refute has_element?(view, "#home-private-reassurance")
    refute has_element?(view, "#home-video-hero a:not(#home-hero-sign-up-link)")
    refute has_element?(view, "#home-video-hero button:not(#home-example-video-play)")
  end

  test "renders a focused benefit-led hero", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")
    assert has_element?(view, "#home-hero-logo")
    assert has_element?(view, "#home-hero-brand", "RationalGrid")
    assert has_element?(view, "#home-hero-title", "Learn today. Remember tomorrow.")
    assert has_element?(view, "#home-hero-subheading", "Go beyond easy answers")
    assert has_element?(view, "#home-concern-comparisons-link[href='/compare']")
    refute has_element?(view, "#home-hero-comparisons-link")
    assert has_element?(view, "#home-hero-background[srcset][sizes='100vw']")
    assert has_element?(view, "#home-concern-ai-link[href='/intro/ai']")
    refute has_element?(view, "#home-ai-scepticism-link")
    assert has_element?(view, "#home-final-sign-up-link", "Create a free account")
    refute has_element?(view, "#home-try-reassurance")
    refute has_element?(view, "#home-video-hero [aria-label='Learn today and remember tomorrow']")
  end

  test "signed-in users start privately in My Learning", %{conn: conn} do
    {:ok, view, _html} = conn |> log_in_user(user_fixture()) |> live(~p"/")

    assert has_element?(
             view,
             "#home-hero-start-grid-link[href='/my/learning?new=true']",
             "Create a grid"
           )

    assert has_element?(view, "#home-final-start-grid-link[href='/my/learning?new=true']")
    refute has_element?(view, "#home-video-hero a:not(#home-hero-start-grid-link)")
    assert has_element?(view, "#home-learning-start-grid-link[href='/my/learning?new=true']")
    refute has_element?(view, "#new-idea-form")
    refute has_element?(view, "#home-hero-sign-up-link")
  end

  test "shows the product briefly and links to the detailed pages", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#home-video-hero #home-hero-tour #home-example-video")
    refute has_element?(view, "#home-product-preview")

    assert has_element?(
             view,
             ~s(#home-footer-guide-link[href="/intro/how"]),
             "Guide"
           )

    assert has_element?(view, "#home-example-video[phx-hook='YouTubeFacade']")
    assert has_element?(view, "#home-example-video-play")

    assert has_element?(
             view,
             ~s(#home-example-video img[src*="rationalgrid-video-preview-768"][srcset][sizes])
           )

    refute has_element?(view, "#home-example-video iframe")
    assert has_element?(view, "#popular-grids h2#home-learning-title")

    assert has_element?(
             view,
             "#home-social-proof #home-testimonial blockquote",
             "An amazing free specialised AI tool"
           )

    assert has_element?(
             view,
             "#home-testimonial [data-testimonial-attribution]",
             "Alexandra Konoplyanik"
           )

    assert has_element?(
             view,
             "#home-testimonial-organization-link[href='https://pfalondon.org/']",
             "Philosophy for All"
           )

    refute has_element?(
             view,
             "#home-testimonial [data-testimonial-attribution]",
             "RationalGrid adviser"
           )

    refute has_element?(view, "#home-social-proof [hidden]")
    refute has_element?(view, "#home-social-proof [phx-hook]")
    refute has_element?(view, "#home-proof-previous")
    refute has_element?(view, "#home-proof-next")
    assert has_element?(view, "#home-research-case-study", "One article. 35 connected ideas.")
    assert has_element?(view, "#home-research-case-study", "Ignacio Gonzalez")

    assert has_element?(
             view,
             "#home-case-study-source-link[href*='philosophynow.org/issues/173'][target='_blank']",
             "Philosophy Now"
           )

    assert has_element?(
             view,
             "#home-case-study-grid-link[href*='inspired-by-the-philosophy-now-article']",
             "Explore the example"
           )

    for {id, url} <- [
          {"youtube", "https://www.youtube.com/channel/UC5PU0sHtxIyvStCVFHoFE-g"},
          {"instagram", "https://instagram.com/rationalgrid.ai"},
          {"tiktok", "https://tiktok.com/@rationalgrid"},
          {"linkedin", "https://www.linkedin.com/company/112287990"},
          {"facebook", "https://facebook.com/1148559478344903"},
          {"x", "https://twitter.com/TJCBerman"}
        ] do
      assert has_element?(
               view,
               "#home-social-links #home-social-#{id}[href='#{url}'][target='_blank'][rel='noopener noreferrer']"
             )
    end

    assert has_element?(view, "#home-social-x", "Tom Berman")

    refute has_element?(view, "#home-definition")

    assert has_element?(view, "#home-ai-limits-faq h2#home-faq-title")
    assert has_element?(view, "#home-faq-cost", "How much does RationalGrid cost?")
    assert has_element?(view, "#home-faq-ai-usage-limits", "What are the AI usage limits?")
    assert has_element?(view, "#home-faq-ai-usage-limits", "three AI requests in progress")
    assert has_element?(view, "#home-concern-sources", "Can I trust the AI?")

    assert has_element?(
             view,
             "#home-concern-chat-assistants",
             "Why not just use ChatGPT?"
           )

    assert has_element?(
             view,
             "#home-concern-chat-assistants",
             "Organise them by topic in My Learning"
           )

    assert has_element?(
             view,
             ~s(#home-concern-ai-link[href="/intro/ai"]),
             "How AI and sources work"
           )

    assert has_element?(
             view,
             "footer p.text-slate-400",
             "Your AI workshop."
           )
  end

  test "keeps the homepage focused on signup with the video in the hero", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(
             view,
             "#home-video-hero + #home-social-proof + #popular-grids + #home-before-you-start + #home-ai-limits-faq + #home-final-cta + footer"
           )

    for location <- ["hero", "final"] do
      assert has_element?(
               view,
               "#home-#{location}-sign-up-link[href='/users/register?return_to=%2Fmy%2Flearning%3Fnew%3Dtrue']"
             )
    end

    refute has_element?(view, "#new-idea-form")
  end

  test "explains both starting points and how to build on an idea", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(
             view,
             "#popular-grids #home-learning-steps > #home-learning-ask + #home-learning-explore"
           )

    assert has_element?(
             view,
             "#home-learning-start-grid-link[href='/users/register?return_to=%2Fmy%2Flearning%3Fnew%3Dtrue']",
             "Create a grid"
           )

    assert has_element?(view, "#home-learning-ask", "first AI answer")

    assert has_element?(
             view,
             "#home-learning-explore #home-community-grids-link[href='/community']"
           )

    assert has_element?(
             view,
             "#home-learning-elaborate",
             "Ask a follow-up question, add your own thought or challenge an answer"
           )

    refute has_element?(view, "#new-idea-form")
  end

  test "existing prompt links move to My Learning with the question", %{conn: conn} do
    assert {:error, {:live_redirect, %{to: path}}} =
             live(conn, ~p"/?initial_prompt=Why%20do%20habits%20persist%3F&focus=grid#start-here")

    assert URI.parse(path).path == "/my/learning"

    assert URI.decode_query(URI.parse(path).query) == %{
             "new" => "true",
             "initial_prompt" => "Why do habits persist?"
           }
  end

  test "the concerns explain source limits and privacy without hiding answers", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")
    assert has_element?(view, "#home-concern-sources", "Simple answers")
    assert has_element?(view, "#home-concern-sources", "Expanded or In-depth")
    assert has_element?(view, "#home-concern-sources", "AI can be wrong")
    assert has_element?(view, "#home-concern-privacy", "start private")
    assert has_element?(view, "#home-concerns > article:nth-child(3)")
    refute has_element?(view, "#home-concerns details")
    refute has_element?(view, "#home-faq-sources")
    refute has_element?(view, "#home-faq-chat-assistants")
    refute has_element?(view, "#home-ai-limits-faq details:nth-child(10)")
    refute has_element?(view, "#new-idea-level-step")
  end

  test "practical questions cover ongoing exploration and the former About introduction", %{
    conn: conn
  } do
    {:ok, view, _html} = live(conn, ~p"/")

    for id <-
          ~w(complex-questions recall organise-learning thinking-tools who-is-it-for community-contributions) do
      assert has_element?(view, "#home-ai-limits-faq #home-faq-#{id} > summary")
    end

    assert has_element?(view, "#home-faq-complex-questions p", "a day, a month or a year later")
    assert has_element?(view, "#home-faq-complex-questions p", "Grid history")
    assert has_element?(view, "#home-faq-recall p", "Try explaining an idea")
    assert has_element?(view, "#home-faq-organise-learning p", "Collections")
    assert has_element?(view, "#home-faq-thinking-tools p", "Philosophy for All")
    assert has_element?(view, "#home-faq-who-is-it-for p", "Journalists and writers")
  end

  test "all answer levels are included with a free account", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(
             view,
             "#home-faq-ai-usage-limits",
             "A free account includes Simple, Expanded and In-depth answers"
           )

    refute has_element?(view, "#answer-level-login-modal")
  end

  test "logged in users find profile and settings together in Account", %{conn: conn} do
    user = user_fixture()
    {:ok, user} = Accounts.update_user_profile(user, %{username: "headerprofile"})

    html =
      conn
      |> log_in_user(user)
      |> get(~p"/")
      |> html_response(200)

    document = LazyHTML.from_document(html)

    assert document
           |> LazyHTML.query("#account-menu #account-profile-link")
           |> LazyHTML.attribute("href") == ["/u/headerprofile"]

    assert document
           |> LazyHTML.query("#account-menu #account-settings-link")
           |> LazyHTML.attribute("href") == ["/users/settings"]

    assert document |> LazyHTML.query("#site-navigation-links > a") |> LazyHTML.attribute("id") ==
             ["my-learning-nav-link", "community-nav-link", "desktop-new-grid-nav-link"]

    assert document |> LazyHTML.query("#account-curate-link") |> LazyHTML.attribute("href") == []
  end
end
