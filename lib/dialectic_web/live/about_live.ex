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
       "Learn about RationalGrid's mission to improve public understanding and discourse using AI-powered collaborative knowledge mapping."
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
      <div class="relative mx-auto max-w-5xl px-6 py-24 sm:py-32 text-center">
        <div class="flex items-center justify-center gap-3 mb-6">
          <img src={~p"/images/favicon.webp"} alt="RationalGrid" class="h-12 w-12" />
        </div>
        <h1 class="text-4xl sm:text-5xl lg:text-6xl font-extrabold tracking-tight mb-6">
          About RationalGrid
        </h1>
        <p class="mx-auto max-w-2xl text-lg sm:text-xl text-white/80 leading-relaxed">
          Transforming how people explore ideas, engage with arguments, and build shared understanding — one node at a time. Start your own grid now and share it if you want.
        </p>
        <div class="mt-10 flex items-center justify-center gap-2 text-white/50 text-sm">
          <.icon name="hero-arrow-down" class="w-5 h-5 animate-bounce" />
          <span>Scroll to learn more</span>
        </div>
      </div>
    </section>

    <%!-- 2. Mission & Vision --%>
    <section class="bg-slate-50 py-20">
      <div class="mx-auto max-w-4xl px-6">
        <div class="text-center mb-8">
          <div class="inline-flex items-center gap-2">
            <h2 class="text-3xl font-bold text-gray-900">Mission &amp; Vision</h2>
            <span class="inline-flex items-center rounded-full bg-amber-100 px-3 py-1 text-xs font-semibold text-amber-800 ring-1 ring-inset ring-amber-300">
              <.icon name="hero-wrench-screwdriver" class="w-3.5 h-3.5 mr-1" /> Work in Progress
            </span>
          </div>
        </div>
        <div class="relative rounded-2xl bg-white p-8 sm:p-12 shadow-lg ring-1 ring-gray-200">
          <div class="absolute -top-4 left-8">
            <div class="flex h-8 w-8 items-center justify-center rounded-full bg-[#3a0ca3] text-white">
              <.icon name="hero-chat-bubble-bottom-center-text" class="w-4 h-4" />
            </div>
          </div>
          <blockquote class="text-xl sm:text-2xl font-medium text-gray-800 leading-relaxed italic">
            "To improve public understanding and learning around serious concepts, arguments and discourse using AI tools in a not-for-profit, open access environment."
          </blockquote>
          <div class="mt-6 flex items-center gap-2 text-sm text-gray-500">
            <.icon name="hero-heart" class="w-4 h-4 text-[#3a0ca3]" />
            <span>Open access · Not-for-profit · Community-driven</span>
          </div>
        </div>
      </div>
    </section>

    <%!-- 3. What is RationalGrid? --%>
    <section class="bg-white py-20">
      <div class="mx-auto max-w-5xl px-6">
        <div class="text-center mb-14">
          <h2 class="text-3xl sm:text-4xl font-bold text-gray-900 mb-4">
            What is RationalGrid?
          </h2>
          <p class="text-gray-500 max-w-2xl mx-auto">
            A new kind of tool for a clearer new kind of thinking.
          </p>
        </div>

        <div class="grid gap-10 md:grid-cols-2">
          <div class="rounded-2xl bg-gradient-to-br from-purple-50 to-blue-50 p-8 ring-1 ring-purple-100">
            <div class="flex items-center gap-3 mb-4">
              <div class="flex h-10 w-10 items-center justify-center rounded-xl bg-[#3a0ca3] text-white">
                <.icon name="hero-globe-alt" class="w-5 h-5" />
              </div>
              <h3 class="text-xl font-bold text-gray-900">Helping Critical Thinking</h3>
            </div>
            <p class="text-gray-700 leading-relaxed">
              We live in an era of unprecedented information access, yet the quality of discourse often feels lacking. Echo chambers and motivated reasoning lead to people talking past each other rather than engaging meaningfully. We built RationalGrid because we believe meaningful exchanges happen when you can explore assumptions at a fundamental level and see how reasonable people can hold conflicting values and opinions.
            </p>
          </div>

          <div class="rounded-2xl bg-gradient-to-br from-blue-50 to-indigo-50 p-8 ring-1 ring-blue-100">
            <div class="flex items-center gap-3 mb-4">
              <div class="flex h-10 w-10 items-center justify-center rounded-xl bg-[#4361ee] text-white">
                <.icon name="hero-academic-cap" class="w-5 h-5" />
              </div>
              <h3 class="text-xl font-bold text-gray-900">
                Active Learning, Not Passive Consumption
              </h3>
            </div>
            <p class="text-gray-700 leading-relaxed">
              Large Language Models provide unprecedented access to knowledge, but traditional AI chat interfaces limit their potential for deep learning. RationalGrid transforms AI interaction into an active, exploratory process where learners branch out in multiple directions, creating a personalized knowledge map that evolves with their curiosity.
            </p>
          </div>
        </div>
      </div>
    </section>

    <%!-- 5. Key Capabilities --%>
    <section class="bg-slate-50 py-20">
      <div class="mx-auto max-w-5xl px-6">
        <div class="text-center mb-6">
          <h2 class="text-3xl sm:text-4xl font-bold text-gray-900 mb-4">What It Does</h2>
          <p class="text-gray-500 max-w-2xl mx-auto">
            Start building your grid by typing a thought, question or provocation.
            Sign up, fill in your profile and keep your grids and ideas in easy view.
          </p>
        </div>
        <div class="text-center mb-14">
          <p class="text-gray-500 max-w-2xl mx-auto text-sm">
            Powerful tools designed for deep exploration and collaboration.
          </p>
        </div>

        <div class="grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
          <div class="rounded-xl bg-gray-50 p-6 ring-1 ring-gray-200 hover:shadow-md transition">
            <div class="flex h-10 w-10 items-center justify-center rounded-lg bg-[#3a0ca3]/10 text-[#3a0ca3] mb-4">
              <.icon name="hero-share" class="w-5 h-5" />
            </div>
            <h3 class="font-bold text-gray-900 mb-2">Grow Your Grid</h3>
            <p class="text-sm text-gray-600 leading-relaxed">
              Every response becomes a node (seen as a box) in your knowledge grid, revealing connections, suggesting ideas and enabling non-linear exploration.
            </p>
          </div>

          <div class="rounded-xl bg-gray-50 p-6 ring-1 ring-gray-200 hover:shadow-md transition">
            <div class="flex h-10 w-10 items-center justify-center rounded-lg bg-[#3a0ca3]/10 text-[#3a0ca3] mb-4">
              <.icon name="hero-magnifying-glass" class="w-5 h-5" />
            </div>
            <h3 class="font-bold text-gray-900 mb-2">Deep Dive If You Wish</h3>
            <p class="text-sm text-gray-600 leading-relaxed">
              Highlight any term — or node — to instantly explore its meaning, implications, and connections within your knowledge map.
            </p>
          </div>

          <div class="rounded-xl bg-gray-50 p-6 ring-1 ring-gray-200 hover:shadow-md transition">
            <div class="flex h-10 w-10 items-center justify-center rounded-lg bg-[#3a0ca3]/10 text-[#3a0ca3] mb-4">
              <.icon name="hero-users" class="w-5 h-5" />
            </div>
            <h3 class="font-bold text-gray-900 mb-2">You're Not Alone</h3>
            <p class="text-sm text-gray-600 leading-relaxed">
              Collaborate with other users in real-time on shared knowledge maps. Think together, explore together, learn together. Other AI tools don't offer this.
            </p>
          </div>

          <div class="rounded-xl bg-gray-50 p-6 ring-1 ring-gray-200 hover:shadow-md transition">
            <div class="flex h-10 w-10 items-center justify-center rounded-lg bg-[#3a0ca3]/10 text-[#3a0ca3] mb-4">
              <.icon name="hero-document-text" class="w-5 h-5" />
            </div>
            <h3 class="font-bold text-gray-900 mb-2">Persistent &amp; Searchable</h3>
            <p class="text-sm text-gray-600 leading-relaxed">
              Every grid you create is saved (unless you delete it) and fully searchable. Build a personal library of explored ideas.
            </p>
          </div>

          <div class="rounded-xl bg-gray-50 p-6 ring-1 ring-gray-200 hover:shadow-md transition">
            <div class="flex h-10 w-10 items-center justify-center rounded-lg bg-[#3a0ca3]/10 text-[#3a0ca3] mb-4">
              <.icon name="hero-arrow-down-tray" class="w-5 h-5" />
            </div>
            <h3 class="font-bold text-gray-900 mb-2">Portable Output</h3>
            <p class="text-sm text-gray-600 leading-relaxed">
              Export your knowledge graphs as PDF, JSON, or Markdown. Your work goes where you need it. You can share your grid to your networks or social media if you want.
            </p>
          </div>

          <div class="rounded-xl bg-gray-50 p-6 ring-1 ring-gray-200 hover:shadow-md transition">
            <div class="flex h-10 w-10 items-center justify-center rounded-lg bg-[#3a0ca3]/10 text-[#3a0ca3] mb-4">
              <.icon name="hero-cursor-arrow-rays" class="w-5 h-5" />
            </div>
            <h3 class="font-bold text-gray-900 mb-2">AI-Powered Branching</h3>
            <p class="text-sm text-gray-600 leading-relaxed">
              Explore the pros and cons, comparisons and differentiators of your ideas and arguments from any node. Let curiosity guide the path.
            </p>
          </div>
        </div>

        <%!-- Additional capabilities --%>
        <div class="mt-14">
          <h3 class="text-xl font-bold text-gray-900 mb-6 text-center">Additional Capabilities</h3>
          <div class="grid gap-6 sm:grid-cols-2">
            <div class="rounded-xl bg-gradient-to-br from-purple-50 to-blue-50 p-6 ring-1 ring-purple-100 hover:shadow-md transition">
              <div class="flex items-center gap-3 mb-3">
                <div class="flex h-10 w-10 items-center justify-center rounded-lg bg-[#3a0ca3]/10 text-[#3a0ca3]">
                  <.icon name="hero-presentation-chart-bar" class="w-5 h-5" />
                </div>
                <h4 class="font-bold text-gray-900">Presentation Mode</h4>
              </div>
              <p class="text-sm text-gray-600 leading-relaxed">
                Edit and highlight the key points from your grid that you most want to share — for meetings, lectures, conferences, social media or big screens. Get your audience engaged swiftly, while enabling them to drill down into your detailed grid separately, on demand.
              </p>
            </div>

            <div class="rounded-xl bg-gradient-to-br from-blue-50 to-indigo-50 p-6 ring-1 ring-blue-100 hover:shadow-md transition">
              <div class="flex items-center gap-3 mb-3">
                <div class="flex h-10 w-10 items-center justify-center rounded-lg bg-[#4361ee]/10 text-[#4361ee]">
                  <.icon name="hero-star" class="w-5 h-5" />
                </div>
                <h4 class="font-bold text-gray-900">Highlighted Grids</h4>
              </div>
              <p class="text-sm text-gray-600 leading-relaxed">
                Users like you are creating hundreds of grids on RationalGrid. We try to highlight the best of them on our home page. We will also be running a series of "curated grids" featuring ideas being explored by invited guests.
                <.link
                  href="mailto:hello@rationalgrid.ai"
                  class="font-medium text-[#3a0ca3] hover:underline"
                >
                  Get in touch
                </.link>
                if you'd like to be considered.
              </p>
            </div>
          </div>
        </div>
      </div>
    </section>

    <%!-- 6. For Educators --%>
    <section class="bg-gradient-to-br from-indigo-50 to-purple-50 py-20">
      <div class="mx-auto max-w-5xl px-6">
        <div class="grid gap-10 md:grid-cols-2 items-center">
          <div>
            <div class="flex items-center gap-3 mb-4">
              <div class="flex h-10 w-10 items-center justify-center rounded-xl bg-[#3a0ca3] text-white">
                <.icon name="hero-academic-cap" class="w-5 h-5" />
              </div>
              <h2 class="text-3xl font-bold text-gray-900">For Educators</h2>
            </div>
            <p class="text-gray-700 leading-relaxed mb-6">
              RationalGrid is a powerful classroom tool. Students can explore complex topics collaboratively, map out arguments visually, and develop critical thinking skills through structured inquiry.
            </p>
            <ul class="space-y-3">
              <li class="flex items-start gap-3">
                <.icon name="hero-check-circle" class="w-5 h-5 text-emerald-600 mt-0.5 shrink-0" />
                <span class="text-gray-700">Students explore topics at their own pace and depth</span>
              </li>
              <li class="flex items-start gap-3">
                <.icon name="hero-check-circle" class="w-5 h-5 text-emerald-600 mt-0.5 shrink-0" />
                <span class="text-gray-700">
                  Shared whiteboards enable real-time group discussion
                </span>
              </li>
              <li class="flex items-start gap-3">
                <.icon name="hero-check-circle" class="w-5 h-5 text-emerald-600 mt-0.5 shrink-0" />
                <span class="text-gray-700">
                  Visual argument maps develop critical thinking skills
                </span>
              </li>
              <li class="flex items-start gap-3">
                <.icon name="hero-check-circle" class="w-5 h-5 text-emerald-600 mt-0.5 shrink-0" />
                <span class="text-gray-700">Free and open access — no paywall, no gatekeeping</span>
              </li>
            </ul>
          </div>
          <div class="flex items-center justify-center">
            <div class="relative rounded-2xl bg-white p-8 shadow-lg ring-1 ring-gray-200 max-w-sm">
              <div class="absolute -top-3 -right-3 flex h-8 w-8 items-center justify-center rounded-full bg-amber-400 text-white text-xs font-bold shadow">
                <.icon name="hero-light-bulb" class="w-4 h-4" />
              </div>
              <div class="flex items-center gap-3 mb-4">
                <div class="h-10 w-10 rounded-full bg-purple-100 flex items-center justify-center">
                  <.icon name="hero-user-group" class="w-5 h-5 text-[#3a0ca3]" />
                </div>
                <div>
                  <div class="text-sm font-semibold text-gray-900">Classroom Session</div>
                  <div class="text-xs text-gray-500">5 students exploring</div>
                </div>
              </div>
              <div class="space-y-2">
                <div class="rounded-lg bg-purple-50 px-3 py-2 text-xs text-gray-700">
                  "What makes an argument valid?"
                </div>
                <div class="ml-4 rounded-lg bg-blue-50 px-3 py-2 text-xs text-gray-700">
                  ↳ Exploring: logical structure vs. truth
                </div>
                <div class="ml-8 rounded-lg bg-indigo-50 px-3 py-2 text-xs text-gray-700">
                  ↳ Comparing: deductive vs. inductive reasoning
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>

    <%!-- 7. Testimonial --%>
    <section class="bg-white py-20">
      <div class="mx-auto max-w-3xl px-6 text-center">
        <div class="flex justify-center mb-6">
          <div class="flex h-14 w-14 items-center justify-center rounded-full bg-purple-100">
            <.icon name="hero-chat-bubble-left-right" class="w-7 h-7 text-[#3a0ca3]" />
          </div>
        </div>
        <blockquote class="text-xl sm:text-2xl font-medium text-gray-800 leading-relaxed italic mb-6">
          "An amazing free specialised AI tool to explore philosophical ideas around pretty much anything — from academic questions to films to… hamsters! All at one's fingertips, in a matter of seconds, with in-built tools for a sophisticated, yet accessible dialectic. Bravo!"
        </blockquote>
        <div class="flex items-center justify-center gap-3">
          <div class="h-10 w-10 rounded-full bg-gradient-to-br from-[#3a0ca3] to-[#4361ee] flex items-center justify-center text-white font-bold text-sm">
            AK
          </div>
          <div class="text-left">
            <div class="font-semibold text-gray-900">Alexandra Konoplyanik</div>
            <div class="text-sm text-gray-500">
              <.link
                href="https://pfalondon.org/"
                target="_blank"
                rel="noopener noreferrer"
                class="text-[#3a0ca3] hover:underline"
              >
                Philosophy for All
              </.link>
            </div>
          </div>
        </div>
      </div>
    </section>

    <%!-- 8. Partners Section --%>
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

        <div class="grid gap-8 sm:grid-cols-2 lg:grid-cols-4">
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
              <img src={~p"/images/martin.webp"} alt="Martin Loat" class="h-full w-full object-cover" />
            </div>
            <h3 class="font-bold text-gray-900">Martin Loat</h3>
            <p class="text-sm text-gray-500">Partnerships Director</p>
          </div>

          <%!-- Placeholder: Education Advisor --%>
          <div class="text-center">
            <div class="mx-auto mb-4 flex h-24 w-24 items-center justify-center rounded-full bg-gray-100 text-gray-300 shadow">
              <.icon name="hero-user-circle" class="w-12 h-12" />
            </div>
            <h3 class="font-bold text-gray-400">Coming Soon</h3>
            <p class="text-sm text-gray-300">Education Advisor</p>
          </div>

          <%!-- Placeholder: Research Partner --%>
          <div class="text-center">
            <div class="mx-auto mb-4 flex h-24 w-24 items-center justify-center rounded-full bg-gray-100 text-gray-300 shadow">
              <.icon name="hero-user-circle" class="w-12 h-12" />
            </div>
            <h3 class="font-bold text-gray-400">Coming Soon</h3>
            <p class="text-sm text-gray-300">Research Partner</p>
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
                Tom created RationalGrid out of a conviction that AI could do much more than answer questions in a linear chat — it could help people actually think. The idea was to build a tool where every response becomes a node in a living knowledge map, letting users branch, compare, and explore ideas visually rather than scrolling through walls of text.
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
        </div>
      </div>
    </section>

    <%!-- How It's Built --%>
    <section class="bg-slate-50 py-20">
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
              <h3 class="font-bold text-gray-900">OpenAI</h3>
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
        <h2 class="text-3xl sm:text-4xl font-bold mb-4">Ready to explore?</h2>
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
            <.icon name="hero-sparkles" class="w-5 h-5" /> Start Exploring
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
            RationalGrid is open source. Explore the code, report issues, or contribute.
          </p>
          <.link
            href="https://github.com/TomBers/dialectic"
            target="_blank"
            rel="noopener noreferrer"
            class="inline-flex items-center gap-2 text-white/80 hover:text-white text-sm font-medium transition"
          >
            <svg class="h-5 w-5" fill="currentColor" viewBox="0 0 24 24">
              <path
                fill-rule="evenodd"
                d="M12 2C6.477 2 2 6.484 2 12.017c0 4.425 2.865 8.18 6.839 9.504.5.092.682-.217.682-.483 0-.237-.008-.868-.013-1.703-2.782.605-3.369-1.343-3.369-1.343-.454-1.158-1.11-1.466-1.11-1.466-.908-.62.069-.608.069-.608 1.003.07 1.531 1.032 1.531 1.032.892 1.53 2.341 1.088 2.91.832.092-.647.35-1.088.636-1.338-2.22-.253-4.555-1.113-4.555-4.951 0-1.093.39-1.988 1.029-2.688-.103-.253-.446-1.272.098-2.65 0 0 .84-.27 2.75 1.026A9.564 9.564 0 0112 6.844c.85.004 1.705.115 2.504.337 1.909-1.296 2.747-1.027 2.747-1.027.546 1.379.202 2.398.1 2.651.64.7 1.028 1.595 1.028 2.688 0 3.848-2.339 4.695-4.566 4.943.359.309.678.92.678 1.855 0 1.338-.012 2.419-.012 2.747 0 .268.18.58.688.482A10.019 10.019 0 0022 12.017C22 6.484 17.522 2 12 2z"
                clip-rule="evenodd"
              />
            </svg>
            View on GitHub <.icon name="hero-arrow-top-right-on-square" class="w-3.5 h-3.5" />
          </.link>
        </div>
      </div>
    </section>
    """
  end
end
