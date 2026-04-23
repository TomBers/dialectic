defmodule DialecticWeb.AboutLive do
  use DialecticWeb, :live_view

  on_mount {DialecticWeb.UserAuth, :mount_current_user}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "About RationalGrid")
     |> assign(:contact_mailto, "mailto:hello@rationalgrid.ai")
     |> assign(
       :page_description,
       "Learn how RationalGrid helps people map arguments, concepts, and complex subjects in a persistent shared grid."
     )
     |> assign(
       :feedback_form,
       to_form(
         %{
           "feedback_type" => "Comments",
           "feedback" => "",
           "suggestions" => "",
           "name" => "",
           "email" => ""
         },
         as: :feedback
       )
     )
     |> assign(:feedback_submitted, false)
     |> assign(:feedback_submitting, false)}
  end

  @impl true
  def handle_event("submit_feedback", %{"feedback" => params}, socket) do
    feedback = Map.get(params, "feedback", "")

    if String.trim(feedback) == "" do
      {:noreply,
       socket
       |> assign(:feedback_form, to_form(params, as: :feedback))
       |> put_flash(:error, "Please enter some feedback before submitting.")}
    else
      {:noreply,
       socket
       |> assign(:feedback_submitting, true)
       |> assign(:feedback_form, to_form(params, as: :feedback))
       |> start_async(:submit_feedback, fn -> Dialectic.Feedback.submit(params) end)}
    end
  end

  @impl true
  def handle_async(:submit_feedback, {:ok, {:ok, :submitted}}, socket) do
    {:noreply,
     socket
     |> assign(:feedback_submitting, false)
     |> assign(:feedback_submitted, true)
     |> put_flash(:info, "Thank you for your feedback!")}
  end

  def handle_async(:submit_feedback, {:ok, {:error, _reason}}, socket) do
    {:noreply,
     socket
     |> assign(:feedback_submitting, false)
     |> put_flash(:error, "Something went wrong submitting your feedback. Please try again.")}
  end

  def handle_async(:submit_feedback, {:exit, _reason}, socket) do
    {:noreply,
     socket
     |> assign(:feedback_submitting, false)
     |> put_flash(:error, "Something went wrong submitting your feedback. Please try again.")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <%!-- 1. Hero Section --%>
    <section class="relative overflow-hidden bg-gradient-to-br from-[#3a0ca3] to-[#4361ee] text-white">
      <div class="absolute inset-0 opacity-10">
        <div class="absolute top-10 left-10 w-72 h-72 bg-white rounded-full blur-3xl"></div>
        <div class="absolute bottom-10 right-10 w-96 h-96 bg-purple-300 rounded-full blur-3xl"></div>
      </div>
      <div class="relative mx-auto max-w-5xl px-6 py-24 sm:py-32">
        <div class="mx-auto max-w-3xl text-center">
          <p class="inline-flex items-center gap-2 rounded-full bg-white/10 px-4 py-2 text-xs font-semibold uppercase tracking-[0.18em] text-white/80 ring-1 ring-white/20">
            <.icon name="hero-heart" class="w-3.5 h-3.5" />
            Open access · Not-for-profit · Built for serious topics
          </p>
        </div>

        <div class="mt-6 flex items-center justify-center gap-3">
          <img src={~p"/images/favicon.webp"} alt="RationalGrid" class="h-12 w-12" />
        </div>

        <div class="mx-auto mt-6 max-w-3xl text-center">
          <h1 class="text-4xl sm:text-5xl lg:text-6xl font-extrabold tracking-tight">
            RationalGrid helps you think through ideas that do not fit in a chat box.
          </h1>
          <p class="mx-auto mt-6 max-w-2xl text-lg sm:text-xl text-white/85 leading-relaxed">
            Use it to map arguments, concepts, evidence, and counterarguments in a shared
            visual grid. Instead of losing the thread in a long conversation, you build a
            structure you can inspect, improve, and revisit.
          </p>
          <p class="mx-auto mt-4 max-w-2xl text-base text-white/70 leading-relaxed">
            It is designed for learning, teaching, research, and public reasoning around
            topics where the relationships between ideas matter.
          </p>

          <div class="mt-8 flex flex-wrap items-center justify-center gap-3 text-sm text-white/75">
            <span class="rounded-full bg-white/10 px-4 py-2 ring-1 ring-white/15">
              Arguments &amp; counterarguments
            </span>
            <span class="rounded-full bg-white/10 px-4 py-2 ring-1 ring-white/15">
              Source texts &amp; concepts
            </span>
            <span class="rounded-full bg-white/10 px-4 py-2 ring-1 ring-white/15">
              Revision &amp; teaching
            </span>
            <span class="rounded-full bg-white/10 px-4 py-2 ring-1 ring-white/15">
              Shared inquiry
            </span>
          </div>

          <div class="mt-10 flex flex-col items-center justify-center gap-4 sm:flex-row">
            <.link
              navigate={~p"/"}
              class={[
                "inline-flex items-center gap-2 rounded-xl px-6 py-3 text-base font-semibold",
                "bg-white text-[#3a0ca3] shadow-lg hover:bg-white/95 hover:shadow-xl transition"
              ]}
            >
              <.icon name="hero-sparkles" class="w-5 h-5" /> Start a grid
            </.link>
            <.link
              navigate={~p"/intro/how"}
              class={[
                "inline-flex items-center gap-2 rounded-xl px-6 py-3 text-base font-semibold",
                "bg-white/10 text-white ring-1 ring-white/25 hover:bg-white/20 transition"
              ]}
            >
              <.icon name="hero-book-open" class="w-5 h-5" /> Read the guide
            </.link>
          </div>
        </div>
      </div>
    </section>

    <%!-- 2. What it is for --%>
    <section class="bg-white py-20">
      <div class="mx-auto max-w-5xl px-6">
        <div class="text-center mb-12">
          <h2 class="text-3xl sm:text-4xl font-bold text-gray-900 mb-4">Why RationalGrid exists</h2>
          <p class="mx-auto max-w-3xl text-gray-600">
            The point is simple: help people build understanding around complex subjects
            without flattening them into a disposable stream of replies.
          </p>
        </div>

        <div class="grid gap-6 md:grid-cols-3">
          <div class="rounded-2xl bg-slate-50 p-8 ring-1 ring-slate-200">
            <p class="text-sm font-semibold uppercase tracking-wide text-[#3a0ca3]">Used for</p>
            <h3 class="mt-3 text-xl font-bold text-gray-900">Questions that branch</h3>
            <p class="mt-4 text-gray-700 leading-relaxed">
              Use RationalGrid when you need to compare positions, unpack a text, follow
              evidence, or teach a difficult concept without reducing it to one answer.
            </p>
          </div>

          <div class="rounded-2xl bg-slate-50 p-8 ring-1 ring-slate-200">
            <p class="text-sm font-semibold uppercase tracking-wide text-[#3a0ca3]">
              Why it exists
            </p>
            <h3 class="mt-3 text-xl font-bold text-gray-900">Understanding needs structure</h3>
            <p class="mt-4 text-gray-700 leading-relaxed">
              Serious topics are rarely linear. RationalGrid makes the shape of a
              discussion visible so people can see how claims connect, where disagreements
              sit, and what still needs explaining.
            </p>
          </div>

          <div class="rounded-2xl bg-slate-50 p-8 ring-1 ring-slate-200">
            <p class="text-sm font-semibold uppercase tracking-wide text-[#3a0ca3]">
              Different from chat
            </p>
            <h3 class="mt-3 text-xl font-bold text-gray-900">
              Built for understanding, not just output
            </h3>
            <p class="mt-4 text-gray-700 leading-relaxed">
              ChatGPT and Claude are excellent at producing responses. RationalGrid turns
              responses into a persistent map you can inspect, share, and keep improving.
            </p>
          </div>
        </div>
      </div>
    </section>

    <%!-- 3. Comparison --%>
    <section class="bg-slate-50 py-20">
      <div class="mx-auto max-w-5xl px-6">
        <div class="text-center mb-12">
          <h2 class="text-3xl sm:text-4xl font-bold text-gray-900 mb-4">
            Why people use this instead of starting another chat
          </h2>
          <p class="mx-auto max-w-3xl text-gray-600">
            RationalGrid complements tools like ChatGPT and Claude by preserving the
            structure, collaboration, and memory that chat interfaces tend to lose.
          </p>
        </div>

        <div class="grid gap-6 md:grid-cols-3">
          <div class="rounded-2xl bg-white p-8 ring-1 ring-gray-200 shadow-sm">
            <div class="flex h-12 w-12 items-center justify-center rounded-xl bg-indigo-50 text-indigo-600">
              <.icon name="hero-map" class="w-6 h-6" />
            </div>
            <h3 class="mt-5 text-xl font-bold text-gray-900">See the whole argument</h3>
            <p class="mt-3 text-gray-700 leading-relaxed">
              A chat gives you the latest reply. RationalGrid keeps the surrounding
              branches, tradeoffs, and related ideas visible at the same time.
            </p>
          </div>

          <div class="rounded-2xl bg-white p-8 ring-1 ring-gray-200 shadow-sm">
            <div class="flex h-12 w-12 items-center justify-center rounded-xl bg-sky-50 text-sky-600">
              <.icon name="hero-user-group" class="w-6 h-6" />
            </div>
            <h3 class="mt-5 text-xl font-bold text-gray-900">Work on the same map</h3>
            <p class="mt-3 text-gray-700 leading-relaxed">
              Share one grid with classmates, colleagues, or collaborators instead of
              copying fragments between separate chat sessions.
            </p>
          </div>

          <div class="rounded-2xl bg-white p-8 ring-1 ring-gray-200 shadow-sm">
            <div class="flex h-12 w-12 items-center justify-center rounded-xl bg-violet-50 text-violet-600">
              <.icon name="hero-circle-stack" class="w-6 h-6" />
            </div>
            <h3 class="mt-5 text-xl font-bold text-gray-900">Keep what you learn</h3>
            <p class="mt-3 text-gray-700 leading-relaxed">
              Your work stays useful as reference and revision material instead of sinking
              into old chat history.
            </p>
          </div>
        </div>

        <div class="mt-10 rounded-2xl bg-white p-6 sm:p-8 ring-1 ring-gray-200 shadow-sm">
          <div class="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
            <div class="text-left">
              <p class="text-sm font-semibold uppercase tracking-wide text-[#3a0ca3]">
                Want the feature walkthrough?
              </p>
              <p class="mt-1 text-gray-600">
                The guide covers the workflow, interface, and product capabilities in detail.
              </p>
            </div>
            <.link
              navigate={~p"/intro/how"}
              class="inline-flex items-center justify-center gap-2 rounded-xl bg-[#3a0ca3] px-5 py-3 text-sm font-semibold text-white shadow-sm transition hover:bg-[#4361ee]"
            >
              <.icon name="hero-book-open" class="w-4 h-4" /> Go to the guide
            </.link>
          </div>
        </div>
      </div>
    </section>

    <%!-- 4. Partners Section --%>
    <section class="bg-slate-50 py-20">
      <div class="mx-auto max-w-5xl px-6">
        <div class="text-center mb-14">
          <h2 class="text-3xl sm:text-4xl font-bold text-gray-900 mb-4">Our Partners</h2>
          <p class="text-gray-500 max-w-2xl mx-auto">
            Working together to make knowledge more accessible.
          </p>
        </div>

        <div class="grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
          <%!-- Philosophy for All - real partner --%>
          <div class="rounded-2xl bg-white p-6 shadow-sm ring-1 ring-gray-200 hover:shadow-md transition">
            <div class="flex h-20 items-center justify-center rounded-xl bg-purple-50 mb-4">
              <div class="flex items-center gap-2 text-[#3a0ca3]">
                <.icon name="hero-academic-cap" class="w-8 h-8" />
                <span class="text-lg font-bold">PfA</span>
              </div>
            </div>
            <h3 class="font-bold text-gray-900 mb-1">Philosophy for All</h3>
            <p class="text-sm text-gray-600 mb-3">
              A London-based charity making philosophy accessible to everyone through free events and workshops.
            </p>
            <.link
              href="https://pfalondon.org/"
              target="_blank"
              rel="noopener noreferrer"
              class="inline-flex items-center gap-1 text-sm font-medium text-[#3a0ca3] hover:underline"
            >
              Visit website <.icon name="hero-arrow-top-right-on-square" class="w-3.5 h-3.5" />
            </.link>
          </div>

          <%!-- Placeholder partner 1 --%>
          <div class="rounded-2xl bg-white p-6 shadow-sm ring-1 ring-gray-200 border-2 border-dashed border-gray-200">
            <div class="flex h-20 items-center justify-center rounded-xl bg-gray-50 mb-4">
              <div class="text-gray-300">
                <.icon name="hero-building-office-2" class="w-10 h-10" />
              </div>
            </div>
            <h3 class="font-bold text-gray-400 mb-1">Your Organisation Here</h3>
            <p class="text-sm text-gray-400">
              We're looking for educational institutions and non-profits who share our mission of open access learning.
            </p>
          </div>

          <%!-- Placeholder partner 2 --%>
          <div class="rounded-2xl bg-white p-6 shadow-sm ring-1 ring-gray-200 border-2 border-dashed border-gray-200">
            <div class="flex h-20 items-center justify-center rounded-xl bg-gray-50 mb-4">
              <div class="text-gray-300">
                <.icon name="hero-heart" class="w-10 h-10" />
              </div>
            </div>
            <h3 class="font-bold text-gray-400 mb-1">Partner With Us</h3>
            <p class="text-sm text-gray-400">
              Join a growing community dedicated to improving discourse and critical thinking through technology.
            </p>
          </div>
        </div>

        <div class="mt-10 text-center">
          <p class="text-gray-500">
            Interested in partnering with us? <.link
              href={@contact_mailto}
              class="font-medium text-[#3a0ca3] hover:underline"
            >
              Get in touch
            </.link>.
          </p>
        </div>
      </div>
    </section>

    <%!-- 9. The Team --%>
    <section class="bg-white py-20">
      <div class="mx-auto max-w-5xl px-6">
        <div class="text-center mb-14">
          <h2 class="text-3xl sm:text-4xl font-bold text-gray-900 mb-4">
            The People Behind RationalGrid
          </h2>
          <p class="text-gray-500 max-w-2xl mx-auto">
            Built with care by a small, passionate team.
          </p>
        </div>

        <div class="space-y-8">
          <div class="grid gap-8 sm:grid-cols-3">
            <%!-- Tom Berman --%>
            <div class="text-center group">
              <div class="mx-auto mb-4 h-24 w-24 overflow-hidden rounded-full shadow-lg group-hover:shadow-xl transition">
                <img src={~p"/images/tom.webp"} alt="Tom Berman" class="h-full w-full object-cover" />
              </div>
              <h3 class="font-bold text-gray-900">Tom Berman</h3>
              <p class="text-sm text-gray-500 mb-3">Founder &amp; Developer</p>
              <div class="flex items-center justify-center gap-3">
                <.link
                  href="https://github.com/TomBers"
                  target="_blank"
                  rel="noopener noreferrer"
                  aria-label="Tom Berman GitHub profile (opens in a new tab)"
                  class="text-gray-400 hover:text-gray-700 transition"
                >
                  <svg class="h-5 w-5" fill="currentColor" viewBox="0 0 24 24">
                    <path
                      fill-rule="evenodd"
                      d="M12 2C6.477 2 2 6.484 2 12.017c0 4.425 2.865 8.18 6.839 9.504.5.092.682-.217.682-.483 0-.237-.008-.868-.013-1.703-2.782.605-3.369-1.343-3.369-1.343-.454-1.158-1.11-1.466-1.11-1.466-.908-.62.069-.608.069-.608 1.003.07 1.531 1.032 1.531 1.032.892 1.53 2.341 1.088 2.91.832.092-.647.35-1.088.636-1.338-2.22-.253-4.555-1.113-4.555-4.951 0-1.093.39-1.988 1.029-2.688-.103-.253-.446-1.272.098-2.65 0 0 .84-.27 2.75 1.026A9.564 9.564 0 0112 6.844c.85.004 1.705.115 2.504.337 1.909-1.296 2.747-1.027 2.747-1.027.546 1.379.202 2.398.1 2.651.64.7 1.028 1.595 1.028 2.688 0 3.848-2.339 4.695-4.566 4.943.359.309.678.92.678 1.855 0 1.338-.012 2.419-.012 2.747 0 .268.18.58.688.482A10.019 10.019 0 0022 12.017C22 6.484 17.522 2 12 2z"
                      clip-rule="evenodd"
                    />
                  </svg>
                </.link>
              </div>
            </div>

            <%!-- Martin Loat --%>
            <div class="text-center group">
              <div class="mx-auto mb-4 h-24 w-24 overflow-hidden rounded-full shadow-lg group-hover:shadow-xl transition">
                <img
                  src={~p"/images/martin.webp"}
                  alt="Martin Loat"
                  class="h-full w-full object-cover"
                />
              </div>
              <h3 class="font-bold text-gray-900">Martin Loat</h3>
              <p class="text-sm text-gray-500">Partnerships Director</p>
            </div>

            <%!-- Maya Darmon --%>
            <div class="text-center group">
              <div class="mx-auto mb-4 h-24 w-24 overflow-hidden rounded-full shadow-lg group-hover:shadow-xl transition">
                <img src={~p"/images/maya.webp"} alt="Maya Darmon" class="h-full w-full object-cover" />
              </div>
              <h3 class="font-bold text-gray-900">Maya Darmon</h3>
              <p class="text-sm text-gray-500">Grid Curator</p>
            </div>
          </div>

          <div class="grid gap-8 sm:grid-cols-2 sm:max-w-xl sm:mx-auto">
            <%!-- Peter Worley - Advisor --%>
            <div class="text-center group">
              <div class="mx-auto mb-4 h-24 w-24 overflow-hidden rounded-full shadow-lg group-hover:shadow-xl transition">
                <img
                  src={~p"/images/pete.webp"}
                  alt="Peter Worley"
                  class="h-full w-full object-cover"
                />
              </div>
              <h3 class="font-bold text-gray-900">Peter Worley</h3>
              <p class="text-sm text-gray-500">Advisor</p>
            </div>

            <%!-- Alexandra Konoplyanik - Advisor --%>
            <div class="text-center group">
              <div class="mx-auto mb-4 h-24 w-24 overflow-hidden rounded-full shadow-lg group-hover:shadow-xl transition">
                <img
                  src={~p"/images/alex.webp"}
                  alt="Alexandra Konoplyanik"
                  class="h-full w-full object-cover"
                />
              </div>
              <h3 class="font-bold text-gray-900">Alexandra Konoplyanik</h3>
              <p class="text-sm text-gray-500">Advisor</p>
            </div>
          </div>
        </div>

        <%!-- Team bios --%>
        <div class="mt-16 max-w-3xl mx-auto space-y-8">
          <div class="rounded-2xl bg-gradient-to-br from-purple-50 to-blue-50 p-8 ring-1 ring-purple-100">
            <div class="flex items-center gap-4 mb-5">
              <div class="h-14 w-14 shrink-0 overflow-hidden rounded-full shadow-lg">
                <img src={~p"/images/tom.webp"} alt="Tom Berman" class="h-full w-full object-cover" />
              </div>
              <div>
                <h3 class="text-lg font-bold text-gray-900">Tom Berman</h3>
                <p class="text-sm text-gray-500">Founder &amp; Developer</p>
              </div>
            </div>
            <div class="space-y-4 text-gray-700 leading-relaxed text-sm">
              <p>
                Tom created RationalGrid out of a conviction that AI could do much more than answer questions in a linear chat — it could help people actually think. The idea was to build a tool where every response becomes a box in a living knowledge map, letting users branch, compare, and expand ideas visually rather than scrolling through walls of text.
              </p>
              <p>
                As the sole developer, Tom designed and built the entire platform from the ground up — the real-time collaborative graph engine, the AI integration layer, the presentation mode, export system, and everything in between. The stack is Elixir and Phoenix LiveView, chosen for their strengths in real-time, concurrent applications.
              </p>
              <p>
                Tom's background spans software engineering and a long-standing interest in philosophy and critical thinking. RationalGrid is where those two worlds meet: a tool built with care to help people reason better, together.
              </p>
            </div>
            <div class="mt-4">
              <.link
                href="https://github.com/TomBers"
                target="_blank"
                rel="noopener noreferrer"
                class="inline-flex items-center gap-1.5 text-sm font-medium text-[#3a0ca3] hover:underline"
              >
                <svg class="h-4 w-4" fill="currentColor" viewBox="0 0 24 24">
                  <path
                    fill-rule="evenodd"
                    d="M12 2C6.477 2 2 6.484 2 12.017c0 4.425 2.865 8.18 6.839 9.504.5.092.682-.217.682-.483 0-.237-.008-.868-.013-1.703-2.782.605-3.369-1.343-3.369-1.343-.454-1.158-1.11-1.466-1.11-1.466-.908-.62.069-.608.069-.608 1.003.07 1.531 1.032 1.531 1.032.892 1.53 2.341 1.088 2.91.832.092-.647.35-1.088.636-1.338-2.22-.253-4.555-1.113-4.555-4.951 0-1.093.39-1.988 1.029-2.688-.103-.253-.446-1.272.098-2.65 0 0 .84-.27 2.75 1.026A9.564 9.564 0 0112 6.844c.85.004 1.705.115 2.504.337 1.909-1.296 2.747-1.027 2.747-1.027.546 1.379.202 2.398.1 2.651.64.7 1.028 1.595 1.028 2.688 0 3.848-2.339 4.695-4.566 4.943.359.309.678.92.678 1.855 0 1.338-.012 2.419-.012 2.747 0 .268.18.58.688.482A10.019 10.019 0 0022 12.017C22 6.484 17.522 2 12 2z"
                    clip-rule="evenodd"
                  />
                </svg>
                GitHub
              </.link>
            </div>
          </div>

          <div class="rounded-2xl bg-gradient-to-br from-purple-50 to-blue-50 p-8 ring-1 ring-purple-100">
            <div class="flex items-center gap-4 mb-5">
              <div class="h-14 w-14 shrink-0 overflow-hidden rounded-full shadow-lg">
                <img
                  src={~p"/images/martin.webp"}
                  alt="Martin Loat"
                  class="h-full w-full object-cover"
                />
              </div>
              <div>
                <h3 class="text-lg font-bold text-gray-900">Martin Loat</h3>
                <p class="text-sm text-gray-500">Partnerships Director</p>
              </div>
            </div>
            <div class="space-y-4 text-gray-700 leading-relaxed text-sm">
              <p>
                After getting a degree in philosophy, Martin started his career in journalism, specialising in business matters (including a stint writing about advertising for The Guardian).
              </p>
              <p>
                Entrepreneurial by nature, he went on to launch and build a B2B public relations agency, which specialised in supporting marketing industry and tech clients. When he sold this company in 2023 it had 50 people working in London and New York and clients including Samsung.
              </p>
              <p>
                Martin is a proven social action campaigner. He was awarded an OBE in 2023 for his voluntary work chairing the Campaign for Equal Civil Partnerships which helped get the law changed and civil partnerships introduced for heterosexual couples in England &amp; Wales in 2019.
              </p>
              <p>
                Martin is now an angel investor, strategic comms advisor and leadership mentor to a number of growing businesses, including in AI.
              </p>
            </div>
          </div>

          <div class="rounded-2xl bg-gradient-to-br from-purple-50 to-blue-50 p-8 ring-1 ring-purple-100">
            <div class="flex items-center gap-4 mb-5">
              <div class="h-14 w-14 shrink-0 overflow-hidden rounded-full shadow-lg">
                <img src={~p"/images/maya.webp"} alt="Maya Darmon" class="h-full w-full object-cover" />
              </div>
              <div>
                <h3 class="text-lg font-bold text-gray-900">Maya Darmon</h3>
                <p class="text-sm text-gray-500">Grid Curator</p>
              </div>
            </div>
            <div class="space-y-4 text-gray-700 leading-relaxed text-sm">
              <p>
                Maya Darmon is a philosophy graduate from Girton College, University of Cambridge, where she developed a strong foundation in critical thinking, logic, and the analysis of complex ideas.
              </p>
              <p>
                Maya is particularly interested in how structured reasoning and collaborative dialogue can be enhanced through technology. She has been involved in exploring tools that augment human thinking, bringing together philosophy and AI to improve how ideas are debated, refined, and understood.
              </p>
              <p>
                At RationalGrid.ai, Maya contributes a philosophical perspective to the design of AI systems, helping ensure that technology supports deeper reasoning, clarity of thought, and meaningful collaboration.
              </p>
            </div>
          </div>
        </div>
      </div>
    </section>

    <%!-- Advisors --%>
    <section class="bg-slate-50 py-20">
      <div class="mx-auto max-w-5xl px-6">
        <div class="text-center mb-14">
          <h2 class="text-3xl sm:text-4xl font-bold text-gray-900 mb-4">Our Advisors</h2>
          <p class="text-gray-500 max-w-2xl mx-auto">
            Expert guidance in philosophy, education, and applied reasoning.
          </p>
        </div>

        <div class="max-w-3xl mx-auto space-y-8">
          <%!-- Peter Worley bio --%>
          <div class="rounded-2xl bg-gradient-to-br from-purple-50 to-blue-50 p-8 ring-1 ring-purple-100">
            <div class="flex items-center gap-4 mb-5">
              <div class="h-14 w-14 shrink-0 overflow-hidden rounded-full shadow-lg">
                <img
                  src={~p"/images/pete.webp"}
                  alt="Peter Worley"
                  class="h-full w-full object-cover"
                />
              </div>
              <div>
                <h3 class="text-lg font-bold text-gray-900">Peter Worley</h3>
                <p class="text-sm text-gray-500">Philosopher, Educator &amp; Author</p>
              </div>
            </div>
            <div class="space-y-4 text-gray-700 leading-relaxed text-sm">
              <p>
                Peter Worley is a philosopher, educator, and co-founder and former CEO of The Philosophy Foundation, a charity bringing philosophy to schools and public settings. He has spent over two decades developing practical approaches to thinking, questioning, and dialogue, and is the creator of PhiE (Philosophical Enquiry), a structured method for facilitating rigorous, collaborative reasoning.
              </p>
              <p>
                An award-winning author of books, including <em>The Philosophy Shop</em>, <em>The If Machine</em>, and <em>Corrupting Youth</em>, his work focuses on making high-quality thinking teachable and transferable. His pedagogy has informed projects such as the BAFTA-nominated BBC programme <em>What Makes Me Me?</em>, the documentary <em>Young Plato</em>, and the BBC prison drama <em>Waiting For The Out</em>.
              </p>
            </div>
            <div class="mt-4">
              <a
                href="https://peterworley.uk/"
                target="_blank"
                rel="noopener noreferrer"
                class="inline-flex items-center gap-1.5 text-sm font-medium text-[#3a0ca3] hover:underline"
              >
                <.icon name="hero-globe-alt" class="w-4 h-4" /> peterworley.uk
                <.icon name="hero-arrow-top-right-on-square" class="w-3.5 h-3.5" />
              </a>
            </div>
          </div>

          <%!-- Alexandra Konoplyanik bio --%>
          <div class="rounded-2xl bg-gradient-to-br from-purple-50 to-blue-50 p-8 ring-1 ring-purple-100">
            <div class="flex items-center gap-4 mb-5">
              <div class="h-14 w-14 shrink-0 overflow-hidden rounded-full shadow-lg">
                <img
                  src={~p"/images/alex.webp"}
                  alt="Alexandra Konoplyanik"
                  class="h-full w-full object-cover"
                />
              </div>
              <div>
                <h3 class="text-lg font-bold text-gray-900">Alexandra Konoplyanik</h3>
                <p class="text-sm text-gray-500">Philosophical Counsellor &amp; Facilitator</p>
              </div>
            </div>
            <div class="space-y-4 text-gray-700 leading-relaxed text-sm">
              <p>
                Alexandra Konoplyanik is a philosophical counsellor and facilitator specialising in applied philosophical enquiry for clearer thinking, better questioning, and collaborative reasoning. She works across education, public philosophy, and professional contexts.
              </p>
              <p>
                She is Secretary and Co-Organiser of Philosophy For All and Social Media Editor at <em>Philosophy Now</em>. She has also worked as a philosophical consultant on digital products, contributing to the conceptual robustness of Lifeaddwiser (employee wellbeing solutions).
              </p>
              <p>
                Before moving into philosophy, Alexandra worked in investment banking and executive search. Her approach focuses on translating philosophical methods into usable formats that help individuals and groups think more clearly and engage productively with complex questions.
              </p>
            </div>
            <div class="mt-4">
              <a
                href="https://alexandrakonoplyanik.com/"
                target="_blank"
                rel="noopener noreferrer"
                class="inline-flex items-center gap-1.5 text-sm font-medium text-[#3a0ca3] hover:underline"
              >
                <.icon name="hero-globe-alt" class="w-4 h-4" /> alexandrakonoplyanik.com
                <.icon name="hero-arrow-top-right-on-square" class="w-3.5 h-3.5" />
              </a>
            </div>
          </div>
        </div>
      </div>
    </section>

    <%!-- How It's Built --%>
    <section class="bg-white py-20">
      <div class="mx-auto max-w-5xl px-6">
        <div class="text-center mb-14">
          <span class="inline-flex items-center rounded-full bg-indigo-100 px-3 py-1 text-xs font-bold text-indigo-700 mb-4">
            <.icon name="hero-wrench-screwdriver" class="w-3.5 h-3.5 mr-1" /> Under the Hood
          </span>
          <h2 class="text-3xl sm:text-4xl font-bold text-gray-900 mb-4">
            How It's Built
          </h2>
          <p class="text-gray-500 max-w-2xl mx-auto">
            RationalGrid is built with modern, battle-tested technologies chosen for real-time collaboration, performance, and reliability.
          </p>
        </div>

        <div class="grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
          <div class="rounded-2xl bg-white p-6 ring-1 ring-gray-100 shadow-sm hover:shadow-md transition">
            <div class="flex items-center gap-3 mb-3">
              <div class="flex h-10 w-10 items-center justify-center rounded-lg bg-purple-100">
                <.icon name="hero-code-bracket" class="w-5 h-5 text-purple-600" />
              </div>
              <h3 class="font-bold text-gray-900">Elixir</h3>
            </div>
            <p class="text-sm text-gray-600 leading-relaxed">
              A functional programming language built on the Erlang VM, designed for building scalable, fault-tolerant, concurrent applications.
            </p>
          </div>

          <div class="rounded-2xl bg-white p-6 ring-1 ring-gray-100 shadow-sm hover:shadow-md transition">
            <div class="flex items-center gap-3 mb-3">
              <div class="flex h-10 w-10 items-center justify-center rounded-lg bg-orange-100">
                <.icon name="hero-bolt" class="w-5 h-5 text-orange-600" />
              </div>
              <h3 class="font-bold text-gray-900">Phoenix LiveView</h3>
            </div>
            <p class="text-sm text-gray-600 leading-relaxed">
              Real-time, server-rendered interactive UIs without writing custom JavaScript. Powers the collaborative graph editing experience over WebSockets.
            </p>
          </div>

          <div class="rounded-2xl bg-white p-6 ring-1 ring-gray-100 shadow-sm hover:shadow-md transition">
            <div class="flex items-center gap-3 mb-3">
              <div class="flex h-10 w-10 items-center justify-center rounded-lg bg-blue-100">
                <.icon name="hero-circle-stack" class="w-5 h-5 text-blue-600" />
              </div>
              <h3 class="font-bold text-gray-900">PostgreSQL</h3>
            </div>
            <p class="text-sm text-gray-600 leading-relaxed">
              A robust, open-source relational database. Stores graphs as JSONB documents for flexible, schema-less node and edge data with full SQL querying.
            </p>
          </div>

          <div class="rounded-2xl bg-white p-6 ring-1 ring-gray-100 shadow-sm hover:shadow-md transition">
            <div class="flex items-center gap-3 mb-3">
              <div class="flex h-10 w-10 items-center justify-center rounded-lg bg-teal-100">
                <.icon name="hero-share" class="w-5 h-5 text-teal-600" />
              </div>
              <h3 class="font-bold text-gray-900">Cytoscape.js</h3>
            </div>
            <p class="text-sm text-gray-600 leading-relaxed">
              An open-source graph visualisation library that renders the interactive knowledge grid — handling layout, navigation, and node interactions in the browser.
            </p>
          </div>

          <div class="rounded-2xl bg-white p-6 ring-1 ring-gray-100 shadow-sm hover:shadow-md transition">
            <div class="flex items-center gap-3 mb-3">
              <div class="flex h-10 w-10 items-center justify-center rounded-lg bg-sky-100">
                <.icon name="hero-paint-brush" class="w-5 h-5 text-sky-600" />
              </div>
              <h3 class="font-bold text-gray-900">Tailwind CSS</h3>
            </div>
            <p class="text-sm text-gray-600 leading-relaxed">
              A utility-first CSS framework for rapidly building custom user interfaces without leaving the markup.
            </p>
          </div>

          <div class="rounded-2xl bg-white p-6 ring-1 ring-gray-100 shadow-sm hover:shadow-md transition">
            <div class="flex items-center gap-3 mb-3">
              <div class="flex h-10 w-10 items-center justify-center rounded-lg bg-violet-100">
                <.icon name="hero-sparkles" class="w-5 h-5 text-violet-600" />
              </div>
              <h3 class="font-bold text-gray-900">Google Gemini</h3>
            </div>
            <p class="text-sm text-gray-600 leading-relaxed">
              AI models generate branching responses, summaries, pros and cons, and comparative analysis — turning questions into rich knowledge maps.
            </p>
          </div>
        </div>

        <div class="mt-10 text-center">
          <p class="text-sm text-gray-500">
            Deployed on <span class="font-semibold text-gray-700">Fly.io</span>
            for
            low-latency global distribution. Fully open source on <a
              href="https://github.com/TomBers/dialectic"
              target="_blank"
              rel="noopener noreferrer"
              class="font-semibold text-[#3a0ca3] hover:underline"
            >GitHub</a>.
          </p>
        </div>
      </div>
    </section>

    <%!-- 10. Feedback Form --%>
    <section class="bg-slate-50 py-20" id="feedback">
      <div class="mx-auto max-w-2xl px-6">
        <div class="text-center mb-10">
          <div class="flex items-center justify-center gap-3 mb-4">
            <div class="flex h-10 w-10 items-center justify-center rounded-xl bg-[#3a0ca3] text-white">
              <.icon name="hero-chat-bubble-left-ellipsis" class="w-5 h-5" />
            </div>
            <h2 class="text-3xl font-bold text-gray-900">We'd Love Your Feedback</h2>
          </div>
          <p class="text-gray-500">
            Help us improve RationalGrid — tell us what's working, what's not, or what you'd like to see.
          </p>
        </div>

        <%= if @feedback_submitted do %>
          <div class="rounded-2xl bg-white p-10 shadow-sm ring-1 ring-gray-200 text-center">
            <div class="flex items-center justify-center mb-4">
              <div class="flex h-14 w-14 items-center justify-center rounded-full bg-emerald-100 text-emerald-600">
                <.icon name="hero-check" class="w-7 h-7" />
              </div>
            </div>
            <h3 class="text-xl font-bold text-gray-900 mb-2">Thank you!</h3>
            <p class="text-gray-500">
              Your feedback has been submitted. We really appreciate you taking the time.
            </p>
          </div>
        <% else %>
          <.form
            for={@feedback_form}
            id="feedback-form"
            phx-submit="submit_feedback"
            class="rounded-2xl bg-white p-8 shadow-sm ring-1 ring-gray-200 space-y-6"
          >
            <div>
              <label for="feedback_type" class="block text-sm font-semibold text-gray-800 mb-2">
                Feedback Type
              </label>
              <select
                id="feedback_type"
                name="feedback[feedback_type]"
                value={@feedback_form[:feedback_type].value}
                class="block w-full rounded-lg border border-gray-300 bg-white px-3 py-2.5 text-sm text-gray-900 shadow-sm focus:border-[#4361ee] focus:ring-2 focus:ring-[#4361ee]/20"
              >
                <option value="Comments" selected={@feedback_form[:feedback_type].value == "Comments"}>
                  General Comment
                </option>
                <option
                  value="Questions"
                  selected={@feedback_form[:feedback_type].value == "Questions"}
                >
                  Question
                </option>
                <option
                  value="Feature Request"
                  selected={@feedback_form[:feedback_type].value == "Feature Request"}
                >
                  Feature Request
                </option>
                <option
                  value="Bug Reports"
                  selected={@feedback_form[:feedback_type].value == "Bug Reports"}
                >
                  Bug Report
                </option>
              </select>
            </div>

            <div>
              <label for="feedback_text" class="block text-sm font-semibold text-gray-800 mb-2">
                Feedback <span class="text-red-500">*</span>
              </label>
              <textarea
                id="feedback_text"
                name="feedback[feedback]"
                rows="4"
                required
                placeholder="What's on your mind?"
                class="block w-full rounded-lg border border-gray-300 bg-white px-3 py-2.5 text-sm text-gray-900 shadow-sm focus:border-[#4361ee] focus:ring-2 focus:ring-[#4361ee]/20 placeholder:text-gray-400"
              >{@feedback_form[:feedback].value}</textarea>
            </div>

            <div>
              <label for="feedback_suggestions" class="block text-sm font-semibold text-gray-800 mb-2">
                Suggestions for improvement
              </label>
              <textarea
                id="feedback_suggestions"
                name="feedback[suggestions]"
                rows="2"
                placeholder="Any ideas on how we could make things better?"
                class="block w-full rounded-lg border border-gray-300 bg-white px-3 py-2.5 text-sm text-gray-900 shadow-sm focus:border-[#4361ee] focus:ring-2 focus:ring-[#4361ee]/20 placeholder:text-gray-400"
              >{@feedback_form[:suggestions].value}</textarea>
            </div>

            <div class="grid gap-4 sm:grid-cols-2">
              <div>
                <label for="feedback_name" class="block text-sm font-semibold text-gray-800 mb-2">
                  Name <span class="text-gray-400 font-normal">(optional)</span>
                </label>
                <input
                  type="text"
                  id="feedback_name"
                  name="feedback[name]"
                  value={@feedback_form[:name].value}
                  placeholder="Your name"
                  class="block w-full rounded-lg border border-gray-300 bg-white px-3 py-2.5 text-sm text-gray-900 shadow-sm focus:border-[#4361ee] focus:ring-2 focus:ring-[#4361ee]/20 placeholder:text-gray-400"
                />
              </div>
              <div>
                <label for="feedback_email" class="block text-sm font-semibold text-gray-800 mb-2">
                  Email <span class="text-gray-400 font-normal">(optional)</span>
                </label>
                <input
                  type="email"
                  id="feedback_email"
                  name="feedback[email]"
                  value={@feedback_form[:email].value}
                  placeholder="you@example.com"
                  class="block w-full rounded-lg border border-gray-300 bg-white px-3 py-2.5 text-sm text-gray-900 shadow-sm focus:border-[#4361ee] focus:ring-2 focus:ring-[#4361ee]/20 placeholder:text-gray-400"
                />
              </div>
            </div>

            <div class="pt-2">
              <button
                type="submit"
                disabled={@feedback_submitting}
                class={[
                  "w-full inline-flex items-center justify-center gap-2 rounded-xl px-6 py-3 text-sm font-semibold text-white shadow-sm transition",
                  "bg-[#3a0ca3] hover:bg-[#4361ee] focus:outline-none focus:ring-2 focus:ring-[#4361ee]/50 focus:ring-offset-2",
                  @feedback_submitting && "opacity-60 cursor-not-allowed"
                ]}
              >
                <%= if @feedback_submitting do %>
                  <.icon name="hero-arrow-path" class="w-4 h-4 animate-spin" /> Submitting...
                <% else %>
                  <.icon name="hero-paper-airplane" class="w-4 h-4" /> Send Feedback
                <% end %>
              </button>
            </div>

            <p class="text-xs text-gray-400 text-center">
              You can send feedback without your name or email. If you choose to provide them, your contact details will be submitted with your feedback and may be stored.
            </p>
          </.form>
        <% end %>
      </div>
    </section>

    <%!-- 11. CTA / Footer --%>
    <section class="bg-gradient-to-br from-[#3a0ca3] to-[#4361ee] py-20 text-white">
      <div class="mx-auto max-w-3xl px-6 text-center">
        <h2 class="text-3xl sm:text-4xl font-bold mb-4">Ready to expand?</h2>
        <p class="text-white/70 text-lg mb-10 max-w-xl mx-auto">
          Start mapping your ideas, challenging assumptions, and building understanding — it's free to use and always will be.
        </p>
        <div class="flex flex-col sm:flex-row items-center justify-center gap-4 mb-14">
          <.link
            navigate={~p"/"}
            class={[
              "inline-flex items-center gap-2 rounded-xl px-6 py-3 text-base font-semibold",
              "bg-white text-[#3a0ca3] shadow-lg hover:bg-white/95 hover:shadow-xl transition"
            ]}
          >
            <.icon name="hero-sparkles" class="w-5 h-5" /> Start Expanding
          </.link>
          <.link
            navigate={~p"/intro/how"}
            class={[
              "inline-flex items-center gap-2 rounded-xl px-6 py-3 text-base font-semibold",
              "bg-white/10 text-white ring-1 ring-white/25 hover:bg-white/20 transition"
            ]}
          >
            <.icon name="hero-book-open" class="w-5 h-5" /> Read the Guide
          </.link>
        </div>

        <div class="border-t border-white/20 pt-8">
          <div class="flex items-center justify-center gap-2 mb-3">
            <.icon name="hero-code-bracket" class="w-5 h-5 text-white/60" />
            <span class="text-white/60 text-sm">Open Source</span>
          </div>
          <p class="text-white/50 text-sm mb-4">
            RationalGrid is open source. View the code, report issues, or contribute.
          </p>
          <div class="flex items-center justify-center gap-6 mb-6">
            <a
              href="https://github.com/TomBers/dialectic"
              target="_blank"
              rel="noopener noreferrer"
              class="text-white/40 hover:text-white/80 transition-colors"
              aria-label="GitHub"
            >
              <svg class="h-6 w-6" fill="currentColor" viewBox="0 0 24 24">
                <path
                  fill-rule="evenodd"
                  d="M12 2C6.477 2 2 6.484 2 12.017c0 4.425 2.865 8.18 6.839 9.504.5.092.682-.217.682-.483 0-.237-.008-.868-.013-1.703-2.782.605-3.369-1.343-3.369-1.343-.454-1.158-1.11-1.466-1.11-1.466-.908-.62.069-.608.069-.608 1.003.07 1.531 1.032 1.531 1.032.892 1.53 2.341 1.088 2.91.832.092-.647.35-1.088.636-1.338-2.22-.253-4.555-1.113-4.555-4.951 0-1.093.39-1.988 1.029-2.688-.103-.253-.446-1.272.098-2.65 0 0 .84-.27 2.75 1.026A9.564 9.564 0 0112 6.844c.85.004 1.705.115 2.504.337 1.909-1.296 2.747-1.027 2.747-1.027.546 1.379.202 2.398.1 2.651.64.7 1.028 1.595 1.028 2.688 0 3.848-2.339 4.695-4.566 4.943.359.309.678.92.678 1.855 0 1.338-.012 2.419-.012 2.747 0 .268.18.58.688.482A10.019 10.019 0 0022 12.017C22 6.484 17.522 2 12 2z"
                  clip-rule="evenodd"
                />
              </svg>
            </a>
            <a
              href="https://x.com/rationalgridai"
              target="_blank"
              rel="noopener noreferrer"
              class="text-white/40 hover:text-white/80 transition-colors"
              aria-label="X (Twitter)"
            >
              <svg class="h-5 w-5" fill="currentColor" viewBox="0 0 24 24">
                <path d="M18.244 2.25h3.308l-7.227 8.26 8.502 11.24H16.17l-5.214-6.817L4.99 21.75H1.68l7.73-8.835L1.254 2.25H8.08l4.713 6.231zm-1.161 17.52h1.833L7.084 4.126H5.117z" />
              </svg>
            </a>
            <a
              href="https://www.instagram.com/rationalgrid/"
              target="_blank"
              rel="noopener noreferrer"
              class="text-white/40 hover:text-white/80 transition-colors"
              aria-label="Instagram"
            >
              <svg class="h-6 w-6" fill="currentColor" viewBox="0 0 24 24">
                <path d="M12 2.163c3.204 0 3.584.012 4.85.07 3.252.148 4.771 1.691 4.919 4.919.058 1.265.069 1.645.069 4.849 0 3.205-.012 3.584-.069 4.849-.149 3.225-1.664 4.771-4.919 4.919-1.266.058-1.644.07-4.85.07-3.204 0-3.584-.012-4.849-.07-3.26-.149-4.771-1.699-4.919-4.92-.058-1.265-.07-1.644-.07-4.849 0-3.204.013-3.583.07-4.849.149-3.227 1.664-4.771 4.919-4.919 1.266-.057 1.645-.069 4.849-.069zM12 0C8.741 0 8.333.014 7.053.072 2.695.272.273 2.69.073 7.052.014 8.333 0 8.741 0 12c0 3.259.014 3.668.072 4.948.2 4.358 2.618 6.78 6.98 6.98C8.333 23.986 8.741 24 12 24c3.259 0 3.668-.014 4.948-.072 4.354-.2 6.782-2.618 6.979-6.98.059-1.28.073-1.689.073-4.948 0-3.259-.014-3.667-.072-4.947-.196-4.354-2.617-6.78-6.979-6.98C15.668.014 15.259 0 12 0zm0 5.838a6.162 6.162 0 100 12.324 6.162 6.162 0 000-12.324zM12 16a4 4 0 110-8 4 4 0 010 8zm6.406-11.845a1.44 1.44 0 100 2.881 1.44 1.44 0 000-2.881z" />
              </svg>
            </a>
            <a
              href="https://www.linkedin.com/company/rationalgrid-ai/"
              target="_blank"
              rel="noopener noreferrer"
              class="text-white/40 hover:text-white/80 transition-colors"
              aria-label="LinkedIn"
            >
              <svg class="h-6 w-6" fill="currentColor" viewBox="0 0 24 24">
                <path d="M20.447 20.452h-3.554v-5.569c0-1.328-.027-3.037-1.852-3.037-1.853 0-2.136 1.445-2.136 2.939v5.667H9.351V9h3.414v1.561h.046c.477-.9 1.637-1.85 3.37-1.85 3.601 0 4.267 2.37 4.267 5.455v6.286zM5.337 7.433a2.062 2.062 0 01-2.063-2.065 2.064 2.064 0 112.063 2.065zm1.782 13.019H3.555V9h3.564v11.452zM22.225 0H1.771C.792 0 0 .774 0 1.729v20.542C0 23.227.792 24 1.771 24h20.451C23.2 24 24 23.227 24 22.271V1.729C24 .774 23.2 0 22.222 0h.003z" />
              </svg>
            </a>
          </div>
        </div>
      </div>
    </section>
    """
  end
end
