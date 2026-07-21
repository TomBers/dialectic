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
       "RationalGrid is a not-for-profit learning platform for turning questions into shared, reusable thinking."
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
    <div class="min-h-screen bg-slate-50 text-slate-900">
      <section class="relative overflow-hidden bg-gradient-to-br from-slate-950 via-slate-900 to-teal-950 text-white">
        <div class="mx-auto max-w-5xl px-6 py-16 sm:py-24">
          <div class="max-w-3xl">
            <p class="text-sm font-semibold uppercase tracking-[0.18em] text-teal-200">
              About RationalGrid
            </p>
            <h1 class="mt-4 text-4xl font-semibold tracking-tight sm:text-6xl">
              Better questions deserve somewhere to go.
            </h1>
            <p class="mt-5 max-w-2xl text-lg leading-8 text-slate-300">
              RationalGrid turns AI conversations into visual, shareable trails of questions, answers, evidence, and new directions.
            </p>
            <div class="mt-8 flex flex-wrap gap-3">
              <.link
                navigate={~p"/"}
                class="inline-flex items-center gap-2 rounded-xl bg-teal-300 px-5 py-3 text-sm font-semibold text-slate-950 transition hover:bg-teal-200"
              >
                <.icon name="hero-sparkles" class="h-4 w-4" /> Start a grid
              </.link>
              <.link
                navigate={~p"/intro/how"}
                class="inline-flex items-center gap-2 rounded-xl bg-white/10 px-5 py-3 text-sm font-semibold text-white ring-1 ring-white/25 transition hover:bg-white/20"
              >
                <.icon name="hero-book-open" class="h-4 w-4" /> Read the guide
              </.link>
            </div>
          </div>
        </div>
      </section>

      <main class="mx-auto max-w-5xl px-6 py-12 sm:py-16">
        <div class="grid gap-4 md:grid-cols-2">
          <section class="rounded-2xl bg-white p-6 shadow-sm ring-1 ring-slate-200 sm:p-8">
            <p class="text-xs font-semibold uppercase tracking-wide text-teal-700">What is it?</p>
            <h2 class="mt-2 text-2xl font-semibold tracking-tight">
              A workspace for thinking in public.
            </h2>
            <p class="mt-3 leading-7 text-slate-600">
              A grid keeps the shape of an inquiry visible, so you can follow branches, revisit ideas, and invite others into the same context.
            </p>
          </section>
          <section class="rounded-2xl bg-white p-6 shadow-sm ring-1 ring-slate-200 sm:p-8">
            <p class="text-xs font-semibold uppercase tracking-wide text-teal-700">
              Why does it exist?
            </p>
            <h2 class="mt-2 text-2xl font-semibold tracking-tight">
              Because useful thinking should not disappear.
            </h2>
            <p class="mt-3 leading-7 text-slate-600">
              Chat is excellent for a quick answer. RationalGrid helps you keep the questions, trade-offs, sources, and insights that come after it.
            </p>
          </section>
          <section class="rounded-2xl bg-white p-6 shadow-sm ring-1 ring-slate-200 sm:p-8">
            <p class="text-xs font-semibold uppercase tracking-wide text-teal-700">
              How does it work?
            </p>
            <ol class="mt-3 space-y-3 text-slate-700">
              <li class="flex gap-3">
                <span class="flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-teal-100 text-xs font-bold text-teal-800">
                  1
                </span>
                <span>Start with a question, idea, or copied answer.</span>
              </li>
              <li class="flex gap-3">
                <span class="flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-teal-100 text-xs font-bold text-teal-800">
                  2
                </span>
                <span>Branch into explanations, objections, evidence, and next questions.</span>
              </li>
              <li class="flex gap-3">
                <span class="flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-teal-100 text-xs font-bold text-teal-800">
                  3
                </span>
                <span>Save, share, and keep developing the map.</span>
              </li>
            </ol>
          </section>
          <section class="rounded-2xl bg-white p-6 shadow-sm ring-1 ring-slate-200 sm:p-8">
            <p class="text-xs font-semibold uppercase tracking-wide text-teal-700">Who is it for?</p>
            <h2 class="mt-2 text-2xl font-semibold tracking-tight">
              Anyone working through a question.
            </h2>
            <p class="mt-3 leading-7 text-slate-600">
              Students, researchers, teams, educators, and curious people can use it to make complex topics easier to explore together.
            </p>
          </section>
        </div>

        <section class="mt-10 rounded-2xl border border-teal-200 bg-teal-50 p-6 sm:p-8">
          <p class="text-xs font-semibold uppercase tracking-wide text-teal-700">Is it free?</p>
          <h2 class="mt-2 text-2xl font-semibold tracking-tight">
            Yes. RationalGrid is open access and not-for-profit.
          </h2>
          <p class="mt-3 max-w-3xl leading-7 text-slate-700">
            The project is open source and built to make better shared thinking available to more people.
          </p>
          <div class="mt-5 flex flex-wrap gap-4 text-sm font-semibold">
            <a
              href="https://github.com/TomBers/dialectic"
              target="_blank"
              rel="noopener noreferrer"
              class="inline-flex items-center gap-1.5 text-teal-800 hover:underline"
            >
              <.icon name="hero-code-bracket" class="h-4 w-4" /> View the source
            </a>
            <a
              href={@contact_mailto}
              class="inline-flex items-center gap-1.5 text-teal-800 hover:underline"
            >
              <.icon name="hero-envelope" class="h-4 w-4" /> Contact us
            </a>
          </div>
        </section>

        <section class="mt-10" aria-labelledby="about-team-heading">
          <div class="mb-6 max-w-2xl">
            <p class="text-xs font-semibold uppercase tracking-wide text-teal-700">
              Who is behind it?
            </p>
            <h2 id="about-team-heading" class="mt-2 text-2xl font-semibold tracking-tight sm:text-3xl">
              A small team building a better way to think together.
            </h2>
          </div>
          <div class="grid gap-4 sm:grid-cols-2 lg:grid-cols-5">
            <%= for {name, role, image} <- [
              {"Tom Berman", "Founder and developer", "/images/tom.webp"},
              {"Maya Darmon", "Philosophy and reasoning lead", "/images/maya.webp"},
              {"Martin Loat", "Advisor", "/images/martin.webp"},
              {"Peter Worley", "Advisor", "/images/pete.webp"},
              {"Alexandra Konoplyanik", "Advisor", "/images/alex.webp"}
            ] do %>
              <article class="rounded-2xl bg-white p-4 text-center shadow-sm ring-1 ring-slate-200">
                <img
                  src={image}
                  alt={name}
                  class="mx-auto h-20 w-20 rounded-full object-cover ring-4 ring-teal-50"
                />
                <h3 class="mt-3 text-sm font-semibold text-slate-950">{name}</h3>
                <p class="mt-1 text-xs leading-5 text-slate-500">{role}</p>
              </article>
            <% end %>
          </div>
        </section>

        <section
          id="feedback"
          class="mt-10 rounded-2xl bg-white p-6 shadow-sm ring-1 ring-slate-200 sm:p-8"
        >
          <div class="max-w-2xl">
            <p class="text-xs font-semibold uppercase tracking-wide text-teal-700">
              What should we improve?
            </p>
            <h2 class="mt-2 text-2xl font-semibold tracking-tight">
              Tell us what would make RationalGrid more useful.
            </h2>
          </div>
          <%= if @feedback_submitted do %>
            <div class="mt-6 rounded-xl bg-emerald-50 p-5 text-emerald-800 ring-1 ring-emerald-200">
              <h3 class="font-semibold">Thank you!</h3>
              <p class="mt-1 text-sm">
                Your feedback has been submitted. We really appreciate you taking the time.
              </p>
            </div>
          <% else %>
            <.form
              for={@feedback_form}
              id="feedback-form"
              phx-submit="submit_feedback"
              class="mt-6 space-y-4"
            >
              <div>
                <label for="feedback_text" class="block text-sm font-semibold text-slate-700">
                  Your feedback <span class="text-rose-500">*</span>
                </label>
                <textarea
                  id="feedback_text"
                  name="feedback[feedback]"
                  rows="4"
                  required
                  placeholder="What’s working? What could be clearer?"
                  class="mt-1.5 block w-full rounded-xl border border-slate-300 px-3 py-2.5 text-sm shadow-sm focus:border-teal-500 focus:ring-2 focus:ring-teal-500/20"
                >{@feedback_form[:feedback].value}</textarea>
              </div>
              <div class="grid gap-4 sm:grid-cols-2">
                <div>
                  <label for="feedback_name" class="block text-sm font-semibold text-slate-700">
                    Name <span class="font-normal text-slate-400">(optional)</span>
                  </label>
                  <input
                    id="feedback_name"
                    name="feedback[name]"
                    value={@feedback_form[:name].value}
                    class="mt-1.5 block w-full rounded-xl border border-slate-300 px-3 py-2.5 text-sm shadow-sm focus:border-teal-500 focus:ring-2 focus:ring-teal-500/20"
                  />
                </div>
                <div>
                  <label for="feedback_email" class="block text-sm font-semibold text-slate-700">
                    Email <span class="font-normal text-slate-400">(optional)</span>
                  </label>
                  <input
                    id="feedback_email"
                    type="email"
                    name="feedback[email]"
                    value={@feedback_form[:email].value}
                    class="mt-1.5 block w-full rounded-xl border border-slate-300 px-3 py-2.5 text-sm shadow-sm focus:border-teal-500 focus:ring-2 focus:ring-teal-500/20"
                  />
                </div>
              </div>
              <button
                type="submit"
                disabled={@feedback_submitting}
                class="inline-flex items-center gap-2 rounded-xl bg-slate-950 px-5 py-3 text-sm font-semibold text-white transition hover:bg-slate-800 disabled:cursor-not-allowed disabled:opacity-60"
              >
                <.icon name="hero-paper-airplane" class="h-4 w-4" /> {if @feedback_submitting,
                  do: "Sending…",
                  else: "Send feedback"}
              </button>
            </.form>
          <% end %>
        </section>
      </main>
    </div>
    """
  end
end
