defmodule DialecticWeb.AboutLive do
  use DialecticWeb, :live_view

  on_mount {DialecticWeb.UserAuth, :mount_current_user}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "About RationalGrid",
       contact_mailto: "mailto:hello@rationalgrid.ai",
       page_description:
         "RationalGrid helps people compare views, connect claims to sources, and build shareable maps of their reasoning."
     ), layout: false}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="min-h-screen bg-[#f4f1e9] text-slate-950">
        <header id="about-hero" class="border-b border-stone-300 bg-white">
          <div class="mx-auto grid max-w-6xl gap-8 px-5 py-14 sm:px-8 sm:py-20 lg:grid-cols-[minmax(0,1fr)_18rem] lg:items-end">
            <div class="max-w-4xl">
              <p class="border-l-2 border-teal-700 pl-3 text-xs font-semibold uppercase tracking-[0.2em] text-teal-800">
                About RationalGrid
              </p>
              <h1 class="mt-5 font-serif text-5xl font-semibold leading-[1.02] tracking-tight sm:text-7xl">
                Know what you think—and show how you got there.
              </h1>
              <p id="about-value-proposition" class="mt-5 max-w-3xl text-lg leading-8 text-slate-600">
                RationalGrid is a free, AI-assisted visual thinking tool for people who want to
                compare ideas, connect claims to sources, and build shareable maps of their reasoning.
              </p>
            </div>
            <div class="border-t border-slate-400 pt-4">
              <p class="text-sm leading-6 text-slate-600">
                A free, not-for-profit project with publicly available code on GitHub.
              </p>
              <div class="mt-4 flex flex-wrap gap-4 text-sm font-semibold">
                <.link
                  id="about-start-grid-link"
                  href={~p"/?focus=grid#start-here"}
                  class="hidden border-b border-slate-500 pb-0.5 hover:border-teal-700 hover:text-teal-800 md:inline-flex"
                >
                  Start a grid
                </.link>
                <.link
                  id="about-mobile-community-link"
                  navigate={~p"/community"}
                  class="border-b border-slate-500 pb-0.5 hover:border-teal-700 hover:text-teal-800 md:hidden"
                >
                  Explore community grids
                </.link>
                <.link
                  navigate={~p"/intro/how"}
                  class="border-b border-slate-500 pb-0.5 hover:border-teal-700 hover:text-teal-800"
                >
                  Read the guide
                </.link>
              </div>
            </div>
          </div>
        </header>

        <div class="mx-auto max-w-6xl px-5 py-12 sm:px-8 sm:py-16">
          <section
            id="about-purpose"
            class="grid gap-7 border-b border-slate-400 pb-10 lg:grid-cols-[minmax(18rem,0.7fr)_minmax(0,1.3fr)]"
            aria-labelledby="about-purpose-heading"
          >
            <div>
              <p class="text-xs font-semibold uppercase tracking-[0.2em] text-teal-800">
                Why it exists
              </p>
              <h2
                id="about-purpose-heading"
                class="mt-2 font-serif text-4xl font-semibold tracking-tight"
              >
                Make learning more rewarding.
              </h2>
            </div>
            <p class="text-base leading-7 text-slate-600">
              We started RationalGrid to make learning enjoyable and put AI to thoughtful use.
              We want to give difficult, overlooked questions the depth and discussion they deserve.
            </p>
          </section>

          <section id="about-tools" class="mt-12" aria-labelledby="about-tools-heading">
            <div class="grid gap-5 border-b border-slate-400 pb-5 sm:grid-cols-[minmax(0,1fr)_22rem] sm:items-end">
              <div>
                <p class="text-xs font-semibold uppercase tracking-[0.2em] text-teal-800">
                  Explore + recall
                </p>
                <h2
                  id="about-tools-heading"
                  class="mt-2 font-serif text-4xl font-semibold tracking-tight"
                >
                  What RationalGrid does
                </h2>
              </div>
              <p class="text-sm leading-6 text-slate-600">
                AI helps you explore; the grid preserves the path so you can return, check, and share.
              </p>
            </div>

            <div class="mt-6 grid gap-5 md:grid-cols-3">
              <article id="about-tool-explore" class="border-t-2 border-violet-600 pt-4">
                <h3 class="font-serif text-xl font-semibold">Explore connected ideas</h3>
                <p class="mt-2 text-sm leading-6 text-slate-600">
                  Question any part of an answer, compare other views, and keep each direction in a
                  visible branch instead of losing it in a chat history.
                </p>
              </article>
              <article id="about-tool-check" class="border-t-2 border-teal-600 pt-4">
                <h3 class="font-serif text-xl font-semibold">Check claims and assumptions</h3>
                <p class="mt-2 text-sm leading-6 text-slate-600">
                  Follow claims to sources and use critical-thinking tools developed with Philosophy
                  for All and Peter Worley. Important claims still need checking.
                </p>
              </article>
              <article id="about-tool-keep" class="border-t-2 border-amber-600 pt-4">
                <h3 class="font-serif text-xl font-semibold">Keep and share the thinking</h3>
                <p class="mt-2 text-sm leading-6 text-slate-600">
                  Highlight, bookmark, export, and publish useful paths so you or others can revisit
                  how a view developed.
                </p>
              </article>
            </div>
            <div class="mt-5 flex flex-wrap gap-4 text-sm font-semibold">
              <.link
                id="about-tools-guide-link"
                navigate={~p"/intro/how"}
                class="inline-flex items-center gap-1.5 border-b border-slate-500 pb-0.5 hover:border-teal-700 hover:text-teal-800"
              >
                See how the tools work <.icon name="hero-arrow-right" class="h-4 w-4" />
              </.link>
              <.link
                navigate={~p"/intro/ai"}
                class="inline-flex items-center gap-1.5 border-b border-slate-500 pb-0.5 hover:border-teal-700 hover:text-teal-800"
              >
                How AI and sources work <.icon name="hero-arrow-right" class="h-4 w-4" />
              </.link>
            </div>
          </section>

          <section id="about-audiences" class="mt-12" aria-labelledby="about-audiences-heading">
            <div class="border-b border-slate-400 pb-5">
              <div>
                <p class="text-xs font-semibold uppercase tracking-[0.2em] text-teal-800">
                  Who it serves
                </p>
                <h2
                  id="about-audiences-heading"
                  class="mt-2 font-serif text-4xl font-semibold tracking-tight"
                >
                  Who RationalGrid is for
                </h2>
              </div>
            </div>

            <div class="divide-y divide-stone-300 border-b border-stone-300">
              <article
                id="about-audience-students"
                class="grid gap-2 py-5 sm:grid-cols-[2.5rem_16rem_1fr] sm:items-baseline lg:grid-cols-[2.5rem_20rem_1fr]"
              >
                <p class="font-mono text-xs font-bold text-sky-700">01</p>
                <h3 class="font-serif text-xl font-semibold">Students</h3>
                <p class="max-w-2xl text-sm leading-6 text-slate-600">
                  <strong class="font-semibold text-slate-950">
                    Build a knowledge base that grows with your course.
                  </strong>
                  Connect concepts, examples, and sources in a grid, then revisit saved branches as
                  you revise. Ask follow-up questions to work through gaps in your understanding.
                </p>
              </article>
              <article
                id="about-audience-researchers"
                class="grid gap-2 py-5 sm:grid-cols-[2.5rem_16rem_1fr] sm:items-baseline lg:grid-cols-[2.5rem_20rem_1fr]"
              >
                <p class="font-mono text-xs font-bold text-rose-700">02</p>
                <h3 class="font-serif text-xl font-semibold">Researchers</h3>
                <p class="max-w-2xl text-sm leading-6 text-slate-600">
                  <strong class="font-semibold text-slate-950">
                    Map a field and test your understanding.
                  </strong>
                  Lay out key concepts, competing explanations, and open questions. Use the
                  critical-thinking tools to challenge assumptions and check claims against original
                  sources before deciding what to investigate next.
                </p>
              </article>
              <article
                id="about-audience-writers"
                class="grid gap-2 py-5 sm:grid-cols-[2.5rem_16rem_1fr] sm:items-baseline lg:grid-cols-[2.5rem_20rem_1fr]"
              >
                <p class="font-mono text-xs font-bold text-amber-700">03</p>
                <h3 class="font-serif text-xl font-semibold">Journalists and writers</h3>
                <p class="max-w-2xl text-sm leading-6 text-slate-600">
                  <strong class="font-semibold text-slate-950">
                    Keep the evidence behind the story.
                  </strong>
                  Compare interpretations, connect sources to claims, and keep counterarguments
                  alongside your own. Export the grid to plan a piece of writing, with supporting
                  material you can trace back and check.
                </p>
              </article>
              <article
                id="about-audience-curious-learners"
                class="grid gap-2 py-5 sm:grid-cols-[2.5rem_16rem_1fr] sm:items-baseline lg:grid-cols-[2.5rem_20rem_1fr]"
              >
                <p class="font-mono text-xs font-bold text-teal-800">04</p>
                <h3 class="font-serif text-xl font-semibold">Curious learners</h3>
                <p class="max-w-2xl text-sm leading-6 text-slate-600">
                  <strong class="font-semibold text-slate-950">
                    Turn a passing question into something you can build on.
                  </strong>
                  Follow a topic into new branches, ask for examples or simpler explanations, and
                  bookmark what you want to return to. Your questions and discoveries stay connected
                  for the next time curiosity strikes.
                </p>
              </article>
            </div>
          </section>

          <section id="about-team" class="mt-12" aria-labelledby="about-team-heading">
            <div class="grid gap-5 border-b border-slate-400 pb-5 sm:grid-cols-[minmax(0,1fr)_18rem] sm:items-end">
              <div>
                <p class="text-xs font-semibold uppercase tracking-[0.2em] text-teal-800">
                  People behind the project
                </p>
                <h2
                  id="about-team-heading"
                  class="mt-2 font-serif text-4xl font-semibold tracking-tight"
                >
                  The team behind RationalGrid
                </h2>
              </div>
              <p class="text-sm leading-6 text-slate-600">
                Product, philosophy, education, and independent advice.
              </p>
            </div>
            <div class="mt-6 grid grid-cols-2 gap-x-5 gap-y-8 sm:grid-cols-3 lg:grid-cols-5">
              <%= for {name, role, image} <- [
                {"Tom Berman", "Founder and developer", ~p"/images/tom.webp"},
                {"Maya Darmon", "Philosophy and reasoning lead", ~p"/images/maya.webp"},
                {"Martin Loat", "Advisor", ~p"/images/martin.webp"},
                {"Peter Worley", "Advisor", ~p"/images/pete.webp"},
                {"Alexandra Konoplyanik", "Advisor", ~p"/images/alex.webp"}
              ] do %>
                <article class="border-t border-slate-400 pt-4">
                  <img src={image} alt={name} class="h-20 w-20 rounded-full object-cover" />
                  <h3 class="mt-3 font-serif text-lg font-semibold text-slate-950">{name}</h3>
                  <p class="mt-1 text-xs leading-5 text-slate-700">{role}</p>
                </article>
              <% end %>
            </div>
            <article
              id="about-tom-berman"
              class="mt-8 grid gap-3 border-t border-slate-400 pt-6 lg:grid-cols-[18rem_1fr]"
            >
              <div>
                <h3 class="font-serif text-2xl font-semibold">Tom Berman</h3>
                <a
                  id="about-tom-linkedin"
                  href="https://www.linkedin.com/in/tom-berman-213a4711/"
                  target="_blank"
                  rel="noopener noreferrer"
                  class="mt-2 inline-flex border-b border-slate-500 pb-0.5 text-sm font-semibold hover:border-teal-700 hover:text-teal-800"
                >
                  LinkedIn profile
                </a>
              </div>
              <div class="max-w-3xl space-y-3 text-sm leading-6 text-slate-600">
                <p>
                  Tom was one of the first engineers at Octopus Energy, co-founded Ecopush as CTO,
                  and later led three engineering teams at Limejump. He also worked in software
                  development at IBM Hursley Laboratories, contributing to research on <a
                    id="about-gaiandb-link"
                    href="https://github.com/gaiandb/gaiandb"
                    target="_blank"
                    rel="noopener noreferrer"
                    class="underline hover:text-teal-800"
                  >GaianDB</a>.
                </p>
                <p>
                  He holds an MPhil in Sustainable Development from the University of Cambridge and
                  a BEng in Engineering from the University of Reading.
                </p>
              </div>
            </article>
          </section>

          <section id="about-key-facts" class="mt-12" aria-labelledby="about-key-facts-heading">
            <div class="border-b border-slate-400 pb-5">
              <p class="text-xs font-semibold uppercase tracking-[0.2em] text-teal-800">
                At a glance
              </p>
              <h2
                id="about-key-facts-heading"
                class="mt-2 font-serif text-4xl font-semibold tracking-tight"
              >
                Key facts
              </h2>
            </div>
            <dl class="mt-6 divide-y divide-stone-300 border-y border-stone-300 bg-white">
              <div class="grid gap-1 px-4 py-3 sm:grid-cols-[13rem_1fr]">
                <dt class="font-semibold">Type</dt><dd>
                  Free, not-for-profit software project
                </dd>
              </div>
              <div class="grid gap-1 px-4 py-3 sm:grid-cols-[13rem_1fr]">
                <dt class="font-semibold">Founder</dt><dd>Tom Berman</dd>
              </div>
              <div class="grid gap-1 px-4 py-3 sm:grid-cols-[13rem_1fr]">
                <dt class="font-semibold">Core offering</dt><dd>
                  AI-assisted visual thinking and research grids
                </dd>
              </div>
              <div class="grid gap-1 px-4 py-3 sm:grid-cols-[13rem_1fr]">
                <dt class="font-semibold">Pricing</dt><dd>Free to use, with no paid tiers</dd>
              </div>
              <div class="grid gap-1 px-4 py-3 sm:grid-cols-[13rem_1fr]">
                <dt class="font-semibold">Source code</dt><dd>
                  <a
                    id="about-source-link"
                    class="underline"
                    href="https://github.com/TomBers/dialectic"
                  >
                    Publicly available on GitHub
                  </a>
                </dd>
              </div>
              <div class="grid gap-1 px-4 py-3 sm:grid-cols-[13rem_1fr]">
                <dt class="font-semibold">Contact</dt><dd>
                  <a class="underline" href={@contact_mailto}>hello@rationalgrid.ai</a>
                </dd>
              </div>
            </dl>
          </section>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
