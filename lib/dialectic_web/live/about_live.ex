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
         "Meet the people behind RationalGrid, a free, not-for-profit project for exploring questions and learning together."
     ), layout: false}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="min-h-screen bg-[#f4f1e9] text-slate-950">
        <div class="mx-auto max-w-6xl px-5 py-12 sm:px-8 sm:py-16">
          <section id="about-team" aria-labelledby="about-team-heading">
            <div class="grid gap-5 border-b border-slate-400 pb-5 sm:grid-cols-[minmax(0,1fr)_18rem] sm:items-end">
              <div>
                <p class="text-xs font-semibold uppercase tracking-[0.2em] text-teal-800">
                  People behind the project
                </p>
                <h1
                  id="about-team-heading"
                  class="mt-2 font-serif text-4xl font-semibold tracking-tight"
                >
                  The team behind RationalGrid
                </h1>
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
                  AI workshop with thinking tools, shared grids, and My Learning to organise your work
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
