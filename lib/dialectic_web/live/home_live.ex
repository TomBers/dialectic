defmodule DialecticWeb.HomeLive do
  use DialecticWeb, :live_view
  alias Dialectic.DbActions.Graphs
  import DialecticWeb.GridCardComp

  @social_channels [
    %{
      id: "youtube",
      label: "YouTube",
      icon: "brand-youtube",
      url: "https://www.youtube.com/channel/UC5PU0sHtxIyvStCVFHoFE-g"
    },
    %{
      id: "instagram",
      label: "Instagram",
      icon: "brand-instagram",
      url: "https://instagram.com/rationalgrid.ai"
    },
    %{
      id: "tiktok",
      label: "TikTok",
      icon: "brand-tiktok",
      url: "https://tiktok.com/@rationalgrid"
    },
    %{
      id: "linkedin",
      label: "LinkedIn",
      icon: "brand-linkedin",
      url: "https://www.linkedin.com/company/112287990"
    },
    %{
      id: "facebook",
      label: "Facebook",
      icon: "brand-facebook",
      url: "https://facebook.com/1148559478344903"
    },
    %{
      id: "x",
      label: "X · Tom Berman",
      icon: "brand-twitter-x",
      url: "https://twitter.com/TJCBerman"
    }
  ]

  @homepage_concerns [
    %{
      id: "chat-assistants",
      question: "Why not just use ChatGPT?",
      answer:
        "Use RationalGrid when you want to develop an idea and return to it later. Questions, answers, challenges and sources stay connected in a grid. Organise them by topic in My Learning, then pick up where you left off.",
      link: :comparisons
    },
    %{
      id: "sources",
      question: "Can I trust the AI?",
      answer:
        "AI can be wrong. Treat answers as starting points: ask follow-up questions, challenge claims and check the original sources. Simple answers use general knowledge; choose Expanded or In-depth for source lookup.",
      link: :ai
    },
    %{
      id: "privacy",
      question: "Do I have to share my work?",
      answer:
        "No. Grids you create in My Learning start private. You choose whether to share with specific people or make a grid public. You can explore community grids without publishing your own.",
      link: nil
    }
  ]

  @homepage_faqs [
    %{
      id: "cost",
      question: "How much does RationalGrid cost?",
      answer: "RationalGrid is free to use. There are no paid pricing tiers."
    },
    %{
      id: "ai-usage-limits",
      question: "What are the AI usage limits?",
      answer:
        "A free account includes Simple, Expanded and In-depth answers. Each person can have up to three AI requests in progress and make up to ten AI requests per minute; if a limit is reached, wait and try again."
    },
    %{
      id: "notion-obsidian",
      question: "Can I use RationalGrid with Notion or Obsidian?",
      answer:
        "Yes. You can export the grid as Markdown and continue organising, linking and writing in Notion or Obsidian.",
      notion_obsidian_link?: true
    }
  ]

  on_mount {DialecticWeb.UserAuth, :mount_current_user}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(
       og_image: DialecticWeb.Endpoint.url() <> ~p"/images/graph_live.webp",
       page_title: "RationalGrid",
       partner_grids_empty?: true,
       homepage_faqs: @homepage_faqs,
       homepage_concerns: @homepage_concerns,
       json_ld: homepage_json_ld(),
       page_description:
         "Explore questions with AI, connect ideas and keep your learning organised. Create a free account to explore questions and develop ideas in a grid."
     )
     |> stream_configure(:partner_grids,
       dom_id: fn item ->
         "home-partner-" <>
           (item.graph.slug || Base.url_encode64(item.graph.title, padding: false))
       end
     )
     |> stream(:partner_grids, []), layout: false}
  end

  @impl true
  def handle_params(params, _url, socket) do
    if params["focus"] == "grid" || params["resume"] == "grid" || params["initial_prompt"] do
      creation_params =
        Map.take(params, ~w(initial_prompt resume collection)) |> Map.put("new", "true")

      {:noreply, push_navigate(socket, to: ~p"/my/learning?#{creation_params}")}
    else
      grids = Graphs.list_curated_grids("featured", 3)

      {:noreply,
       socket
       |> assign(:partner_grids_empty?, grids == [])
       |> stream(:partner_grids, grids, reset: true)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.home_content {assigns} />
    </Layouts.app>
    """
  end

  defp home_content(assigns) do
    ~H"""
    <div class="min-h-screen bg-[#f4f1e9] font-sans text-slate-950 antialiased">
      <section
        id="home-video-hero"
        class="relative isolate min-h-[72svh] overflow-hidden border-b border-slate-700 bg-slate-950 text-white sm:min-h-[78svh]"
      >
        <img
          id="home-hero-background"
          src={~p"/images/fractal-branching-tree-1280.webp"}
          srcset={
            "#{~p"/images/fractal-branching-tree-768.webp"} 768w, #{~p"/images/fractal-branching-tree-1280.webp"} 1280w, #{~p"/images/fractal-branching-tree-1536.webp"} 1536w"
          }
          sizes="100vw"
          alt=""
          width="1536"
          height="850"
          fetchpriority="high"
          decoding="async"
          class="absolute inset-0 -z-20 h-full w-full object-cover opacity-55 saturate-[1.15]"
          aria-hidden="true"
        />
        <div class="absolute inset-0 -z-10 bg-[linear-gradient(90deg,rgba(2,6,23,0.94)_0%,rgba(2,6,23,0.72)_48%,rgba(2,6,23,0.54)_100%)]">
        </div>
        <div
          aria-hidden="true"
          class="absolute inset-0 -z-10 bg-[radial-gradient(circle_at_78%_24%,rgba(99,102,241,0.25),transparent_30%),radial-gradient(circle_at_18%_90%,rgba(20,184,166,0.20),transparent_34%),radial-gradient(circle_at_92%_86%,rgba(245,158,11,0.12),transparent_24%)]"
        >
        </div>
        <div
          aria-hidden="true"
          class="absolute inset-x-0 bottom-0 h-1 bg-[linear-gradient(90deg,#2dd4bf_0%,#818cf8_52%,#fbbf24_100%)]"
        >
        </div>

        <div class="mx-auto grid min-h-[72svh] w-full max-w-7xl items-center gap-12 px-5 py-16 sm:min-h-[78svh] sm:px-8 lg:grid-cols-2 lg:items-center lg:px-10">
          <div class="max-w-4xl">
            <p class="flex items-center gap-3 text-xl font-semibold text-slate-200">
              <img
                id="home-hero-logo"
                src={~p"/images/brandmark.svg"}
                alt=""
                width="36"
                height="36"
                class="h-9 w-9 shrink-0"
              />
              <span id="home-hero-brand">RationalGrid</span>
              <span id="home-hero-descriptor" class="text-sm font-normal text-teal-200">
                Your AI workshop
              </span>
            </p>
            <h1
              id="home-hero-title"
              class="mt-7 text-4xl font-semibold leading-[1.08] tracking-[-0.035em] text-white sm:text-5xl xl:text-6xl"
            >
              Learn today. <span class="text-teal-200">Remember tomorrow.</span>
            </h1>
            <p id="home-hero-subheading" class="mt-6 max-w-xl text-lg leading-8 text-slate-200">
              Turn a question into connected ideas, sources and new directions with AI.
              Keep your learning organised in a grid, ready to return to and build on.
            </p>
            <div id="start-here" class="mt-7 scroll-mt-24">
              <.account_action
                id="home-hero"
                current_user={@current_user}
                location="home_hero"
                hero
              />
              <p
                id="home-private-reassurance"
                class="mt-4 flex items-start gap-2 text-sm leading-6 text-slate-300"
              >
                <.icon name="hero-lock-closed" class="mt-1 h-4 w-4 shrink-0 text-teal-200" />
                <span>Free to use. Your grids start private. You choose what to make public.</span>
              </p>
            </div>
          </div>

          <div id="home-hero-tour" class="min-w-0">
            <p class="mb-3 text-sm font-semibold text-teal-100">See how RationalGrid works</p>
            <div class="border border-slate-700 bg-black p-2 shadow-2xl sm:p-3">
              <div
                id="home-example-video"
                class="relative aspect-video w-full overflow-hidden bg-slate-900"
                phx-hook="YouTubeFacade"
                phx-update="ignore"
                data-video-id="nZOqbspGPfY"
                data-video-title="RationalGrid product video"
              >
                <img
                  src={~p"/images/rationalgrid-video-preview-768.webp"}
                  srcset={
                  "#{~p"/images/rationalgrid-video-preview-768.webp"} 768w, #{~p"/images/rationalgrid-video-preview.webp"} 1280w"
                }
                  sizes="(min-width: 1280px) 568px, (min-width: 1024px) 45vw, 100vw"
                  alt="RationalGrid product video preview"
                  width="768"
                  height="432"
                  class="h-full w-full object-cover"
                  loading="eager"
                  decoding="async"
                />
                <button
                  id="home-example-video-play"
                  type="button"
                  class="absolute inset-0 flex items-center justify-center bg-slate-950/30 text-white transition hover:bg-slate-950/45 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-teal-300"
                  aria-label="Play RationalGrid product video"
                >
                  <span class="flex h-16 w-16 items-center justify-center rounded-full bg-teal-300 text-slate-950 shadow-xl transition hover:scale-105">
                    <.icon name="hero-play-solid" class="ml-1 h-8 w-8" />
                  </span>
                </button>
              </div>
            </div>
          </div>
        </div>
      </section>

      <.social_proof />

      <section
        id="popular-grids"
        aria-labelledby="home-learning-title"
        class="relative isolate overflow-hidden border-b border-stone-300 bg-[#fbfaf6]"
      >
        <div
          aria-hidden="true"
          class="absolute inset-x-0 top-0 -z-10 h-44 bg-[linear-gradient(180deg,rgba(45,212,191,0.08),transparent)]"
        >
        </div>
        <div class="mx-auto w-full max-w-7xl px-5 py-8 sm:px-8 sm:py-10 lg:px-10">
          <h2 id="home-learning-title" class="text-2xl font-semibold tracking-tight text-slate-950">
            Two ways to get started
          </h2>
          <.learning_journey current_user={@current_user} />

          <section :if={!@partner_grids_empty?} id="home-partners" class="mt-6">
            <div
              id="home-partner-grids-list"
              phx-update="stream"
              class="grid gap-5 md:grid-cols-2 xl:grid-cols-3"
            >
              <%= for {id, item} <- @streams.partner_grids do %>
                <.grid_card
                  id={id}
                  graph={item.graph}
                  author_name={item.author_name}
                  author_marker="@"
                  variant={:partner}
                  label="Partner grid"
                  show_badge={false}
                  tag_limit={3}
                />
              <% end %>
            </div>
          </section>
        </div>
      </section>

      <section
        id="home-before-you-start"
        aria-labelledby="home-concerns-title"
        class="border-b border-stone-300 bg-white"
      >
        <div class="mx-auto w-full max-w-7xl px-5 py-8 sm:px-8 sm:py-10 lg:px-10">
          <h2 id="home-concerns-title" class="text-2xl font-semibold tracking-tight text-slate-950">
            Before you start
          </h2>
          <div id="home-concerns" class="mt-6 grid gap-6 md:grid-cols-3 md:gap-8">
            <article :for={concern <- @homepage_concerns} id={"home-concern-#{concern.id}"}>
              <h3 class="text-base font-semibold text-slate-950">{concern.question}</h3>
              <p class="mt-2 text-sm leading-6 text-slate-600">{concern.answer}</p>
              <.link
                :if={concern.link == :comparisons}
                id="home-concern-comparisons-link"
                navigate={~p"/compare"}
                class="mt-2 inline-flex min-h-11 items-center gap-2 rounded text-sm font-semibold text-teal-800 underline decoration-teal-800/40 underline-offset-4 hover:text-teal-950 focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-teal-700"
              >
                Compare with other tools <.icon name="hero-arrow-right" class="h-4 w-4" />
              </.link>
              <.link
                :if={concern.link == :ai}
                id="home-concern-ai-link"
                navigate={~p"/intro/ai"}
                class="mt-2 inline-flex min-h-11 items-center gap-2 rounded text-sm font-semibold text-teal-800 underline decoration-teal-800/40 underline-offset-4 hover:text-teal-950 focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-teal-700"
              >
                How AI and sources work <.icon name="hero-arrow-right" class="h-4 w-4" />
              </.link>
            </article>
          </div>
        </div>
      </section>

      <section
        id="home-ai-limits-faq"
        aria-labelledby="home-faq-title"
        class="border-b border-slate-800 bg-slate-900 text-white"
      >
        <div class="mx-auto w-full max-w-7xl px-5 py-8 sm:px-8 sm:py-10 lg:px-10">
          <h2
            id="home-faq-title"
            class="text-xs font-semibold uppercase tracking-[0.2em] text-teal-200"
          >
            Practical questions
          </h2>

          <div class="mt-5 divide-y divide-slate-700 border-y border-slate-700">
            <details :for={faq <- @homepage_faqs} id={"home-faq-#{faq.id}"} class="group py-4">
              <summary class="flex cursor-pointer list-none items-center justify-between gap-4 font-semibold text-white">
                {faq.question}
                <.icon
                  name="hero-plus"
                  class="h-5 w-5 shrink-0 text-teal-300 transition group-open:rotate-45"
                />
              </summary>
              <p class="mt-3 w-full text-sm leading-6 text-slate-300">
                {faq.answer}
                <%= if Map.get(faq, :notion_obsidian_link?, false) do %>
                  <.link
                    id="home-faq-notion-obsidian-link"
                    navigate={~p"/compare/notion-obsidian"}
                    class="font-semibold text-teal-200 underline decoration-teal-400/50 underline-offset-4 hover:text-white"
                  >
                    See the complete Notion and Obsidian research workflow.
                  </.link>
                <% end %>
              </p>
            </details>
          </div>
        </div>
      </section>

      <section id="home-final-cta" class="border-b border-stone-300 bg-[#f4f1e9] text-slate-950">
        <div class="mx-auto flex w-full max-w-5xl flex-col gap-6 px-5 py-12 sm:px-8 sm:py-14 lg:flex-row lg:items-center lg:justify-between">
          <div>
            <p class="text-xs font-semibold uppercase tracking-[0.2em] text-teal-800">
              Your next question
            </p>
            <h2 class="mt-2 font-serif text-3xl font-semibold tracking-tight sm:text-4xl">
              Start something worth returning to.
            </h2>
            <p class="mt-3 max-w-xl text-sm leading-6 text-slate-600">
              Recall what you learned. Check it. Ask your next question.
            </p>
          </div>
          <div class="flex flex-col items-start gap-3 lg:max-w-sm lg:shrink-0 lg:items-end">
            <.account_action id="home-final" current_user={@current_user} location="home_final_cta" />
            <p class="text-sm text-slate-600">You choose who can see your grids.</p>
          </div>
        </div>
      </section>

      <footer class="bg-slate-950 text-slate-300">
        <div class="mx-auto flex w-full max-w-7xl flex-col gap-5 px-5 py-8 sm:flex-row sm:items-center sm:justify-between sm:px-8 lg:px-10">
          <div class="flex items-center gap-3">
            <img
              src={~p"/images/brandmark.svg"}
              alt="RationalGrid"
              width="56"
              height="56"
              class="h-7 w-7"
            />
            <div>
              <p class="font-semibold text-white">RationalGrid</p>
              <p class="text-xs text-slate-400">Your AI workshop.</p>
            </div>
          </div>
          <nav aria-label="Homepage footer" class="flex flex-wrap gap-x-5 gap-y-2 text-sm">
            <.link id="home-footer-guide-link" navigate={~p"/intro/how"} class="hover:text-white">Guide</.link>
            <.link navigate={~p"/intro/ai"} class="hover:text-white">AI &amp; data use</.link>
            <.link id="home-footer-about-link" navigate={~p"/about"} class="hover:text-white">About</.link>
            <.link navigate={~p"/community"} class="hover:text-white">Community</.link>
            <.link navigate={~p"/gallery"} class="hover:text-white">Gallery</.link>
            <.link
              id="home-footer-comparisons-link"
              navigate={~p"/compare"}
              class="hover:text-white"
            >
              Comparisons
            </.link>
            <.link
              id="home-footer-contact-link"
              href="mailto:hello@rationalgrid.ai"
              class="hover:text-white"
            >
              Contact
            </.link>
            <.link
              href="https://github.com/TomBers/dialectic"
              target="_blank"
              rel="noopener noreferrer"
              class="hover:text-white"
            >
              GitHub
            </.link>
          </nav>
        </div>
      </footer>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :location, :string, required: true
  attr :current_user, :any, required: true
  attr :hero, :boolean, default: false

  defp account_action(assigns) do
    ~H"""
    <.link
      id={@id <> if(@current_user, do: "-start-grid-link", else: "-sign-up-link")}
      href={
        if @current_user,
          do: ~p"/my/learning?new=true",
          else: ~p"/users/register?#{%{return_to: ~p"/my/learning?new=true"}}"
      }
      data-preserve-auth-return="false"
      data-analytics-event={if @current_user, do: "start_grid_clicked", else: "sign_up_cta_clicked"}
      data-analytics-location={@location}
      class={[
        "inline-flex min-h-12 items-center justify-center gap-2 rounded-md px-5 py-3 text-base font-semibold transition focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-teal-500",
        if(@hero,
          do: "bg-teal-300 text-slate-950 hover:bg-teal-200",
          else: "bg-teal-800 text-white hover:bg-teal-900"
        )
      ]}
    >
      {if @current_user, do: "Create a grid", else: "Create a free account"}
      <.icon name="hero-arrow-right" class="h-4 w-4" />
    </.link>
    """
  end

  attr :current_user, :any, required: true

  defp learning_journey(assigns) do
    ~H"""
    <ul id="home-learning-steps" class="mt-3 grid gap-4 md:grid-cols-2 md:gap-8">
      <li id="home-learning-ask" class="flex items-start gap-3">
        <.icon name="hero-plus-circle" class="mt-3 h-5 w-5 shrink-0 text-teal-800" />
        <div>
          <h3>
            <.link
              id="home-learning-start-grid-link"
              href={
                if @current_user,
                  do: ~p"/my/learning?new=true",
                  else: ~p"/users/register?#{%{return_to: ~p"/my/learning?new=true"}}"
              }
              data-preserve-auth-return="false"
              data-analytics-event={
                if @current_user, do: "start_grid_clicked", else: "sign_up_cta_clicked"
              }
              data-analytics-location="home_learning_journey"
              class="inline-flex min-h-11 items-center gap-2 rounded text-base font-semibold text-teal-800 underline decoration-teal-800/40 underline-offset-4 hover:text-teal-950 focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-teal-700"
            >
              Create a grid <.icon name="hero-arrow-right" class="h-4 w-4" />
            </.link>
          </h3>
          <p class="text-sm leading-6 text-slate-600">
            <%= if @current_user do %>
              Ask your own question. AI gives you a starting answer to build on.
            <% else %>
              Create a free account and ask your own question. Build a grid from the first AI answer.
            <% end %>
          </p>
        </div>
      </li>
      <li id="home-learning-explore" class="flex items-start gap-3">
        <.icon name="hero-user-group" class="mt-3 h-5 w-5 shrink-0 text-teal-800" />
        <div>
          <h3>
            <.link
              id="home-community-grids-link"
              navigate={~p"/community"}
              data-analytics-event="community_clicked"
              data-analytics-location="home_community"
              class="inline-flex min-h-11 items-center gap-2 rounded text-base font-semibold text-teal-800 underline decoration-teal-800/40 underline-offset-4 hover:text-teal-950 focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-teal-700"
            >
              Explore community grids <.icon name="hero-arrow-right" class="h-4 w-4" />
            </.link>
          </h3>
          <p class="text-sm leading-6 text-slate-600">
            Find a topic someone else has explored. Open their grid, follow the ideas and choose one to take further.
          </p>
        </div>
      </li>
    </ul>
    <p
      id="home-learning-elaborate"
      class="mt-5 border-t border-stone-300 pt-4 text-sm leading-6 text-slate-600"
    >
      <strong class="font-semibold text-slate-950">Then build on an idea.</strong>
      Ask a follow-up question, add your own thought or challenge an answer. Each contribution stays connected, so you can follow how the thinking develops.
    </p>
    """
  end

  defp social_proof(assigns) do
    assigns = assign(assigns, :social_channels, @social_channels)

    ~H"""
    <section
      id="home-social-proof"
      aria-labelledby="home-proof-title"
      class="border-b border-stone-300 bg-[#f4f1e9]"
    >
      <div class="mx-auto w-full max-w-7xl px-5 py-6 sm:px-8 sm:py-8 lg:px-10">
        <h2
          id="home-proof-title"
          class="text-xs font-semibold uppercase tracking-[0.16em] text-teal-800"
        >
          RationalGrid in use
        </h2>
        <div class="mt-4 grid gap-5 md:grid-cols-2 md:gap-10">
          <figure id="home-testimonial">
            <blockquote class="max-w-xl font-serif text-xl leading-7 text-slate-800">
              “An amazing free specialised AI tool to explore philosophical ideas…”
            </blockquote>
            <figcaption class="mt-3 text-sm text-slate-600" data-testimonial-attribution>
              <span class="font-semibold text-slate-950">Alexandra Konoplyanik</span>
              <span aria-hidden="true"> · </span>
              <.link
                id="home-testimonial-organization-link"
                href="https://pfalondon.org/"
                target="_blank"
                rel="noopener noreferrer"
                class="inline-flex min-h-11 items-center rounded font-medium text-teal-800 underline decoration-teal-800/40 underline-offset-4 hover:text-teal-950 focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-teal-700"
              >Philosophy for All</.link>
            </figcaption>
          </figure>
          <article id="home-research-case-study">
            <h3 class="text-base font-semibold text-slate-950">One article. 35 connected ideas.</h3>
            <p class="mt-1 text-sm leading-6 text-slate-600">
              An article by Ignacio Gonzalez in <.link
                id="home-case-study-source-link"
                href="https://philosophynow.org/issues/173/A_Memetic_Analysis_of_Narratives_and_Conspiracies"
                target="_blank"
                rel="noopener noreferrer"
                class="rounded font-medium text-teal-800 underline decoration-teal-800/40 underline-offset-4 hover:text-teal-950 focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-teal-700"
              >Philosophy Now</.link>, explored as a grid of connected questions and ideas.
            </p>
            <.link
              id="home-case-study-grid-link"
              href="https://rationalgrid.ai/g/inspired-by-the-philosophy-now-article-a-memetic-664759?node=1"
              data-analytics-event="case_study_clicked"
              data-analytics-location="home_social_proof"
              class="mt-1 inline-flex min-h-11 items-center gap-2 rounded text-sm font-semibold text-teal-800 underline decoration-teal-800/40 underline-offset-4 hover:text-teal-950 focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-teal-700"
            >Explore the example <.icon name="hero-arrow-up-right" class="h-4 w-4" /></.link>
          </article>
        </div>
        <div class="mt-4 flex flex-wrap items-center gap-x-6 border-t border-stone-300 pt-3">
          <p id="home-social-links-title" class="text-sm font-semibold text-slate-800">
            Follow RationalGrid
          </p>
          <nav
            id="home-social-links"
            aria-labelledby="home-social-links-title"
            class="flex flex-wrap items-center gap-x-5"
          >
            <.link
              :for={channel <- @social_channels}
              id={"home-social-#{channel.id}"}
              href={channel.url}
              target="_blank"
              rel="noopener noreferrer"
              aria-label={"#{channel.label} (opens in a new tab)"}
              data-analytics-event="social_channel_clicked"
              data-analytics-location="home_social_proof"
              data-analytics-channel={channel.id}
              class="inline-flex min-h-11 items-center gap-2 rounded text-sm font-medium text-teal-800 underline decoration-teal-800/40 underline-offset-4 hover:text-teal-950 focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-teal-700"
            >
              <.icon name={channel.icon} class="h-4 w-4 shrink-0" />
              {channel.label}
            </.link>
          </nav>
        </div>
      </div>
    </section>
    """
  end

  defp homepage_json_ld do
    base_url = DialecticWeb.Endpoint.url()
    organization_id = base_url <> "/#organization"
    product_id = base_url <> "/#product"

    Jason.encode!(%{
      "@context" => "https://schema.org",
      "@graph" => [
        %{
          "@type" => "Organization",
          "@id" => organization_id,
          "name" => "RationalGrid",
          "url" => base_url,
          "logo" => base_url <> ~p"/images/brandmark.svg",
          "description" =>
            "RationalGrid is a not-for-profit project building an AI workshop for thinking and learning together.",
          "sameAs" => ["https://github.com/TomBers/dialectic"]
        },
        %{
          "@type" => "SoftwareApplication",
          "@id" => product_id,
          "name" => "RationalGrid",
          "url" => base_url,
          "image" => base_url <> ~p"/images/graph_live.webp",
          "description" =>
            "Learn today. Remember tomorrow. Your AI workshop for connected ideas, sources and challenges, organised and ready to revisit with others.",
          "applicationCategory" => "EducationalApplication",
          "operatingSystem" => "Web",
          "isAccessibleForFree" => true,
          "brand" => %{"@id" => organization_id},
          "offers" => %{
            "@type" => "Offer",
            "url" => base_url,
            "price" => "0.00",
            "priceCurrency" => "USD",
            "availability" => "https://schema.org/InStock"
          }
        },
        %{
          "@type" => "FAQPage",
          "@id" => base_url <> "/#home-before-you-start",
          "mainEntity" =>
            Enum.map(@homepage_concerns ++ @homepage_faqs, fn faq ->
              %{
                "@type" => "Question",
                "name" => faq.question,
                "acceptedAnswer" => %{
                  "@type" => "Answer",
                  "text" => faq.answer
                }
              }
            end)
        }
      ]
    })
  end
end
