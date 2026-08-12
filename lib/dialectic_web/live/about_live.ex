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
       "RationalGrid is an open-source workspace for exploring ideas with AI, thinking clearly, and sharing grids that last."
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
    handle_async(:submit_feedback, {:ok, {:error, :failed}}, socket)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-[#f4f1e9] text-slate-950">
      <header id="about-hero" class="border-b border-stone-300 bg-white">
        <div class="mx-auto grid max-w-6xl gap-8 px-5 py-14 sm:px-8 sm:py-20 lg:grid-cols-[minmax(0,1fr)_18rem] lg:items-end">
          <div class="max-w-4xl">
            <p class="border-l-2 border-teal-700 pl-3 text-xs font-semibold uppercase tracking-[0.2em] text-teal-800">
              About RationalGrid
            </p>
            <h1 class="mt-5 font-serif text-5xl font-semibold leading-[1.02] tracking-tight sm:text-7xl">
              Build understanding others can extend.
            </h1>
            <p class="mt-5 max-w-2xl text-lg leading-8 text-slate-600">
              Turn questions, AI answers, challenges, and sources into a clear map that other people can check and build on.
            </p>
          </div>
          <div class="border-t border-slate-400 pt-4">
            <p class="text-sm leading-6 text-slate-600">
              Free to use, not-for-profit, and built in public by a small team.
            </p>
            <div class="mt-4 flex flex-wrap gap-4 text-sm font-semibold">
              <.link
                id="about-start-grid-link"
                href={~p"/?focus=grid#start-here"}
                class="border-b border-slate-500 pb-0.5 hover:border-teal-700 hover:text-teal-800"
              >
                Start a grid
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

      <main class="mx-auto max-w-6xl px-5 py-12 sm:px-8 sm:py-16">
        <section
          id="about-ai-artifacts"
          class="grid gap-8 border border-slate-700 bg-slate-950 p-6 text-white sm:p-8 lg:grid-cols-[minmax(0,1fr)_20rem]"
        >
          <div>
            <p class="text-xs font-semibold uppercase tracking-[0.2em] text-teal-300">
              Explore + recall
            </p>
            <h2 class="mt-2 font-serif text-3xl font-semibold">
              AI helps you explore. The grid helps you remember.
            </h2>
            <p class="mt-3 max-w-3xl text-sm leading-6 text-slate-300">
              AI can suggest answers, questions, and new directions. You choose what to save, check, connect, and share. Each box holds an idea or source, and the lines show how they connect. The result is a useful map, not another chat lost in your history.
            </p>
          </div>
          <div class="border-t border-slate-700 pt-5 lg:border-l lg:border-t-0 lg:pl-6 lg:pt-0">
            <p class="text-xs font-semibold uppercase tracking-[0.2em] text-amber-300">
              Open by design
            </p>
            <p class="mt-2 text-sm leading-6 text-slate-300">
              Free to use, open source, and not-for-profit. Shared thinking should be easy to check and use again.
            </p>
            <div class="mt-4 flex flex-wrap gap-4 text-sm font-semibold">
              <a
                href="https://github.com/TomBers/dialectic"
                target="_blank"
                rel="noopener noreferrer"
                class="border-b border-slate-400 pb-0.5 hover:border-teal-300 hover:text-teal-200"
              >
                View the source
              </a>
              <a
                href={@contact_mailto}
                class="border-b border-slate-400 pb-0.5 hover:border-teal-300 hover:text-teal-200"
              >
                Contact us
              </a>
            </div>
          </div>
        </section>

        <section id="about-audiences" class="mt-12" aria-labelledby="about-audiences-heading">
          <div class="grid gap-5 border-b border-slate-400 pb-5 sm:grid-cols-[minmax(0,1fr)_22rem] sm:items-end">
            <div>
              <p class="text-xs font-semibold uppercase tracking-[0.2em] text-teal-800">
                RationalGrid for…
              </p>
              <h2
                id="about-audiences-heading"
                class="mt-2 font-serif text-4xl font-semibold tracking-tight"
              >
                Who is it for?
              </h2>
            </div>
            <p class="text-sm leading-6 text-slate-600">
              For anyone who wants to explore an idea, remember what they find, and share the path with others.
            </p>
          </div>

          <div class="divide-y divide-stone-300 border-b border-stone-300">
            <article
              id="about-audience-students"
              class="grid gap-2 py-5 sm:grid-cols-[2.5rem_16rem_1fr] sm:items-baseline lg:grid-cols-[2.5rem_20rem_1fr]"
            >
              <p class="font-mono text-xs font-bold text-sky-700">01</p>
              <h3 class="font-serif text-xl font-semibold">Students and lifelong learners</h3>
              <p class="max-w-2xl text-sm leading-6 text-slate-600">
                Explore a subject at the right level, save useful passages, and return before an essay, exam, or project.
              </p>
            </article>
            <article
              id="about-audience-teachers"
              class="grid gap-2 py-5 sm:grid-cols-[2.5rem_16rem_1fr] sm:items-baseline lg:grid-cols-[2.5rem_20rem_1fr]"
            >
              <p class="font-mono text-xs font-bold text-indigo-700">02</p>
              <h3 class="font-serif text-xl font-semibold">Teachers and tutors</h3>
              <p class="max-w-2xl text-sm leading-6 text-slate-600">
                Set the explanation level, share a grid with a class, and see how each person added to it.
              </p>
            </article>
            <article
              id="about-audience-researchers-writers"
              class="grid gap-2 py-5 sm:grid-cols-[2.5rem_16rem_1fr] sm:items-baseline lg:grid-cols-[2.5rem_20rem_1fr]"
            >
              <p class="font-mono text-xs font-bold text-rose-700">03</p>
              <h3 class="font-serif text-xl font-semibold">
                Researchers, journalists, and writers
              </h3>
              <p class="max-w-2xl text-sm leading-6 text-slate-600">
                Keep questions, sources, and arguments connected while you research a topic or plan a piece of writing.
              </p>
            </article>
            <article
              id="about-audience-debate-organisers"
              class="grid gap-2 py-5 sm:grid-cols-[2.5rem_16rem_1fr] sm:items-baseline lg:grid-cols-[2.5rem_20rem_1fr]"
            >
              <p class="font-mono text-xs font-bold text-violet-700">04</p>
              <h3 class="font-serif text-xl font-semibold">Debate and discussion organisers</h3>
              <p class="max-w-2xl text-sm leading-6 text-slate-600">
                Map the strongest case on each side, attach sources, and keep the discussion focused.
              </p>
            </article>
            <article
              id="about-audience-teams"
              class="grid gap-2 py-5 sm:grid-cols-[2.5rem_16rem_1fr] sm:items-baseline lg:grid-cols-[2.5rem_20rem_1fr]"
            >
              <p class="font-mono text-xs font-bold text-emerald-700">05</p>
              <h3 class="font-serif text-xl font-semibold">Teams and decision-makers</h3>
              <p class="max-w-2xl text-sm leading-6 text-slate-600">
                Compare options, test assumptions, and keep a shared record of why a decision was made.
              </p>
            </article>
            <article
              id="about-audience-book-clubs"
              class="grid gap-2 py-5 sm:grid-cols-[2.5rem_16rem_1fr] sm:items-baseline lg:grid-cols-[2.5rem_20rem_1fr]"
            >
              <p class="font-mono text-xs font-bold text-amber-700">06</p>
              <h3 class="font-serif text-xl font-semibold">Book clubs and study groups</h3>
              <p class="max-w-2xl text-sm leading-6 text-slate-600">
                Ask questions from an exact passage, share highlights, and explore difficult ideas together.
              </p>
            </article>
            <article
              id="about-audience-critical-thinkers"
              class="grid gap-2 py-5 sm:grid-cols-[2.5rem_16rem_1fr] sm:items-baseline lg:grid-cols-[2.5rem_20rem_1fr]"
            >
              <p class="font-mono text-xs font-bold text-teal-700">07</p>
              <h3 class="font-serif text-xl font-semibold">
                Philosophers and critical thinkers
              </h3>
              <p class="max-w-2xl text-sm leading-6 text-slate-600">
                Define key words, question assumptions, compare views, and see what follows from an idea.
              </p>
            </article>
          </div>
        </section>

        <section class="mt-12" aria-labelledby="about-team-heading">
          <div class="grid gap-5 border-b border-slate-400 pb-5 sm:grid-cols-[minmax(0,1fr)_18rem] sm:items-end">
            <div>
              <p class="text-xs font-semibold uppercase tracking-[0.2em] text-teal-800">
                People behind the project
              </p>
              <h2
                id="about-team-heading"
                class="mt-2 font-serif text-4xl font-semibold tracking-tight"
              >
                A small working team.
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
                <p class="mt-1 text-xs leading-5 text-slate-500">{role}</p>
              </article>
            <% end %>
          </div>
        </section>

        <section id="feedback" class="mt-12 border border-stone-300 bg-white p-6 sm:p-8">
          <div class="grid gap-5 border-b border-stone-300 pb-5 sm:grid-cols-[minmax(0,1fr)_18rem] sm:items-end">
            <div>
              <p class="text-xs font-semibold uppercase tracking-[0.2em] text-teal-800">
                Feedback
              </p>
              <h2 class="mt-2 font-serif text-3xl font-semibold">
                What would make RationalGrid more useful?
              </h2>
            </div>
            <p class="text-sm leading-6 text-slate-600">
              Tell us what worked, what was unclear, or what you expected next.
            </p>
          </div>

          <%= if @feedback_submitted do %>
            <div class="mt-6 border-l-4 border-emerald-600 bg-emerald-50 p-5 text-emerald-900">
              <h3 class="font-semibold">Thank you!</h3>
              <p class="mt-1 text-sm">Your feedback has been submitted.</p>
            </div>
          <% else %>
            <.form
              for={@feedback_form}
              id="feedback-form"
              phx-submit="submit_feedback"
              class="mt-6 space-y-5"
            >
              <.input
                field={@feedback_form[:feedback]}
                type="textarea"
                label="Your feedback"
                rows="5"
                required
                placeholder="What worked? What could be clearer?"
                class="mt-2 block w-full rounded-md border border-slate-300 bg-white px-3 py-2.5 text-sm text-slate-950 shadow-sm focus:border-teal-600 focus:outline-none focus:ring-2 focus:ring-teal-100"
              />
              <div class="grid gap-5 sm:grid-cols-2">
                <.input
                  field={@feedback_form[:name]}
                  label="Name (optional)"
                  class="mt-2 block w-full rounded-md border border-slate-300 bg-white px-3 py-2.5 text-sm text-slate-950 shadow-sm focus:border-teal-600 focus:outline-none focus:ring-2 focus:ring-teal-100"
                />
                <.input
                  field={@feedback_form[:email]}
                  type="email"
                  label="Email (optional)"
                  class="mt-2 block w-full rounded-md border border-slate-300 bg-white px-3 py-2.5 text-sm text-slate-950 shadow-sm focus:border-teal-600 focus:outline-none focus:ring-2 focus:ring-teal-100"
                />
              </div>
              <button
                type="submit"
                disabled={@feedback_submitting}
                class="inline-flex items-center gap-2 rounded-md bg-slate-950 px-5 py-3 text-sm font-semibold text-white transition hover:bg-slate-800 disabled:cursor-not-allowed disabled:opacity-60"
              >
                {if @feedback_submitting, do: "Sending…", else: "Send feedback"}
                <.icon name="hero-arrow-right" class="h-4 w-4" />
              </button>
            </.form>
          <% end %>
        </section>
      </main>
    </div>
    """
  end
end
