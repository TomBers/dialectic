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
       "RationalGrid is a not-for-profit, open-source workspace for connected questions and answers."
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
      <header class="border-b border-stone-300 bg-white">
        <div class="mx-auto grid max-w-6xl gap-8 px-5 py-14 sm:px-8 sm:py-20 lg:grid-cols-[minmax(0,1fr)_18rem] lg:items-end">
          <div class="max-w-4xl">
            <p class="border-l-2 border-teal-700 pl-3 text-xs font-semibold uppercase tracking-[0.2em] text-teal-800">
              About RationalGrid
            </p>
            <h1 class="mt-5 font-serif text-5xl font-semibold leading-[1.02] tracking-tight sm:text-7xl">
              Keep the path from question to answer.
            </h1>
            <p class="mt-5 max-w-2xl text-lg leading-8 text-slate-600">
              Answers, objections, evidence, and sources stay attached to the branch that produced them.
            </p>
          </div>
          <div class="border-t border-slate-400 pt-4">
            <p class="text-sm leading-6 text-slate-600">
              Open access, not-for-profit, and built in public by a small team.
            </p>
            <div class="mt-4 flex flex-wrap gap-4 text-sm font-semibold">
              <.link
                navigate={~p"/"}
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
        <section aria-labelledby="about-plain-heading">
          <div class="grid border border-stone-300 bg-white md:grid-cols-2">
            <article class="border-b border-stone-300 p-6 sm:p-8 md:border-r">
              <p class="font-mono text-xs font-bold text-teal-800">01 / WHAT</p>
              <h2 id="about-plain-heading" class="mt-3 font-serif text-3xl font-semibold">
                A map of an inquiry.
              </h2>
              <p class="mt-3 leading-7 text-slate-600">
                Each box holds a question, answer, comment, or source. Lines preserve the context.
              </p>
            </article>
            <article class="border-b border-stone-300 p-6 sm:p-8">
              <p class="font-mono text-xs font-bold text-teal-800">02 / WHY</p>
              <h2 class="mt-3 font-serif text-3xl font-semibold">Chat loses context.</h2>
              <p class="mt-3 leading-7 text-slate-600">
                Important claims disappear in long threads. A grid keeps related ideas together and makes alternatives easy to compare.
              </p>
            </article>
            <article class="border-b border-stone-300 p-6 sm:p-8 md:border-b-0 md:border-r">
              <p class="font-mono text-xs font-bold text-teal-800">03 / HOW</p>
              <h2 class="mt-3 font-serif text-3xl font-semibold">Branch deliberately.</h2>
              <ol class="mt-4 divide-y divide-stone-200 border-y border-stone-200 text-sm text-slate-700">
                <li class="grid grid-cols-[2rem_1fr] gap-3 py-3">
                  <span class="font-mono text-teal-800">1</span>
                  <span>Start with a question or source.</span>
                </li>
                <li class="grid grid-cols-[2rem_1fr] gap-3 py-3">
                  <span class="font-mono text-teal-800">2</span>
                  <span>Branch from the exact idea you want to test.</span>
                </li>
                <li class="grid grid-cols-[2rem_1fr] gap-3 py-3">
                  <span class="font-mono text-teal-800">3</span>
                  <span>Read, edit, present, or share the resulting path.</span>
                </li>
              </ol>
            </article>
            <article class="p-6 sm:p-8">
              <p class="font-mono text-xs font-bold text-teal-800">04 / WHO</p>
              <h2 class="mt-3 font-serif text-3xl font-semibold">For sustained thinking.</h2>
              <p class="mt-3 leading-7 text-slate-600">
                For students, researchers, educators, teams, and independent learners who need more than one answer.
              </p>
            </article>
          </div>
        </section>

        <section class="mt-10 grid gap-6 border border-slate-700 bg-slate-950 p-6 text-white sm:grid-cols-[minmax(0,1fr)_auto] sm:items-center sm:p-8">
          <div>
            <p class="text-xs font-semibold uppercase tracking-[0.2em] text-teal-300">
              Open access
            </p>
            <h2 class="mt-2 font-serif text-3xl font-semibold">
              Free to use. Open source. Not-for-profit.
            </h2>
            <p class="mt-2 max-w-3xl text-sm leading-6 text-slate-300">
              Shared reasoning should be inspectable and reusable.
            </p>
          </div>
          <div class="flex flex-wrap gap-4 text-sm font-semibold">
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
