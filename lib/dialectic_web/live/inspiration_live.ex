defmodule DialecticWeb.InspirationLive do
  use DialecticWeb, :live_view

  alias Phoenix.LiveView.JS

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Question Inspiration")
     |> assign(
       :preference_form,
       to_form(%{"reality" => "50", "timeframe" => "50", "depth" => "50"},
         as: :preferences
       )
     )
     |> assign(:reality, 50)
     |> assign(:timeframe, 50)
     |> assign(:depth, 50)
     |> assign(:questions, [])
     |> assign(:loading, false)}
  end

  @impl true
  def handle_event("update_preferences", %{"preferences" => params}, socket) do
    socket =
      socket
      |> assign(:preference_form, to_form(params, as: :preferences))
      |> assign(:reality, parse_slider_value(params["reality"], 50))
      |> assign(:timeframe, parse_slider_value(params["timeframe"], 50))
      |> assign(:depth, parse_slider_value(params["depth"], 50))

    {:noreply, socket}
  end

  def handle_event("generate_prompt", _, socket) do
    prompt = build_prompt(socket.assigns)

    Task.Supervisor.async_nolink(Dialectic.TaskSupervisor, fn ->
      Dialectic.Inspiration.Generator.generate_questions(prompt)
    end)

    {:noreply, assign(socket, loading: true, questions: [])}
  end

  def handle_event("select_question", %{"question" => question}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/?#{[initial_prompt: question]}")}
  end

  defp parse_slider_value(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} -> int
      :error -> default
    end
  end

  defp parse_slider_value(_, default), do: default

  @impl true
  def handle_info({ref, result}, socket) when is_reference(ref) do
    Process.demonitor(ref, [:flush])

    socket =
      case result do
        {:ok, questions} ->
          assign(socket, loading: false, questions: questions)

        {:error, _} ->
          socket
          |> put_flash(:error, "Failed to generate questions. Please try again.")
          |> assign(loading: false)
      end

    {:noreply, socket}
  end

  def handle_info({:DOWN, _ref, :process, _pid, :normal}, socket) do
    # Task completed normally, result already handled
    {:noreply, socket}
  end

  def handle_info({:DOWN, _ref, :process, _pid, reason}, socket) do
    # Task failed or timed out
    socket =
      socket
      |> put_flash(:error, "Question generation failed: #{inspect(reason)}")
      |> assign(loading: false)

    {:noreply, socket}
  end

  defp build_prompt(assigns) do
    """
    You are a muse for focused curiosity.
    Generate exactly 5 distinct, open-ended questions that are specific, vivid, and easy to grasp without extra setup.
    Each question must be a single sentence, 10–22 words, and clearly invites more than one plausible answer.
    Avoid yes/no questions, trivia, or broad prompts like “What do you think about X?”
    Ensure each question points to a concrete object, mechanism, tension, or scenario.

    Adhere to these stylistic and thematic preferences:

    1. Reality: #{describe_scale(assigns.reality, "Pure Fiction", "Reality-Grounded")}
       - Pure Fiction: invent imagined worlds, scenarios, or hypothetical settings.
       - Reality-Grounded: focus on real-world phenomena, history, science, society, or evidence-based topics.

    2. Timeframe: #{describe_scale(assigns.timeframe, "The Past", "The Future")}
       - Past: root questions in historical events, long-term trends, and origins.
       - Future: emphasise possibilities, scenarios, and foresight.
       - Mid-range: allow present-focused questions connecting past -> present -> future.

    3. Depth: #{describe_scale(assigns.depth, "Beginner/General Audience", "Expert/Technical")}
       - Beginner/General: avoid jargon, explain assumptions, rely on everyday language and analogies.
       - Expert/Technical: assume prior knowledge; reference specific theories, models, methods, or technical debates.

    Output the questions as a JSON array of strings.
    """
  end

  defp describe_scale(value, left, right) do
    cond do
      value < 20 -> "Strongly leaning towards #{left}"
      value < 40 -> "Leaning towards #{left}"
      value > 80 -> "Strongly leaning towards #{right}"
      value > 60 -> "Leaning towards #{right}"
      true -> "Balanced between #{left} and #{right}"
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex h-[calc(100vh-2.5rem)] min-h-[42rem] flex-col overflow-hidden bg-[#f4f1e9] text-slate-950">
      <div class="flex min-h-0 flex-1 flex-col md:flex-row">
        <aside class="z-10 flex w-full flex-col overflow-y-auto border-b border-stone-300 bg-white md:w-[38%] md:border-b-0 md:border-r">
          <div class="p-5 sm:p-7 lg:p-9">
            <p class="border-l-2 border-teal-700 pl-3 text-xs font-semibold uppercase tracking-[0.2em] text-teal-800">
              Question finder
            </p>
            <h1 class="mt-5 font-serif text-4xl font-semibold tracking-tight sm:text-5xl">
              Find a question worth following.
            </h1>
            <p class="mt-4 max-w-xl text-sm leading-6 text-slate-600">
              Set three boundaries. RationalGrid will suggest five concrete starting points, each
              ready to open as a branching grid.
            </p>

            <.form
              for={@preference_form}
              id="inspiration-preferences-form"
              phx-change="update_preferences"
              class="mt-9"
            >
              <div class="divide-y divide-stone-300 border-y border-stone-300">
                <.slider
                  field={@preference_form[:reality]}
                  label="Reality"
                  value={@reality}
                  left_label="Pure fiction"
                  right_label="Reality-grounded"
                />

                <.slider
                  field={@preference_form[:timeframe]}
                  label="Timeframe"
                  value={@timeframe}
                  left_label="Past"
                  right_label="Future"
                />

                <.slider
                  field={@preference_form[:depth]}
                  label="Depth"
                  value={@depth}
                  left_label="Beginner"
                  right_label="Expert"
                />
              </div>

              <button
                id="inspiration-generate-button"
                type="button"
                phx-click="generate_prompt"
                class="mt-7 inline-flex w-full items-center justify-between rounded-md bg-slate-950 px-5 py-3 text-base font-semibold text-white transition hover:bg-slate-800 focus:outline-none focus:ring-2 focus:ring-teal-700 focus:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50"
                disabled={@loading}
              >
                <span>{if @loading, do: "Finding questions…", else: "Find five questions"}</span>
                <.icon name="hero-arrow-right" class="h-5 w-5" />
              </button>
            </.form>
          </div>
        </aside>

        <main class="relative flex min-h-0 flex-1 flex-col overflow-hidden">
          <div class="flex items-end justify-between gap-5 border-b border-stone-300 bg-[#f4f1e9] px-5 py-5 sm:px-8 lg:px-10">
            <div>
              <p class="text-xs font-semibold uppercase tracking-[0.2em] text-teal-800">
                Starting points
              </p>
              <h2 class="mt-1 font-serif text-3xl font-semibold tracking-tight">
                Questions shaped by your choices
              </h2>
            </div>
            <span class="hidden font-mono text-xs text-slate-500 sm:block">01 → 05</span>
          </div>

          <div class="flex-1 overflow-y-auto px-5 py-7 sm:px-8 lg:px-10 lg:py-9">
            <div
              :if={@loading}
              class="mx-auto max-w-3xl border-l-4 border-teal-700 bg-white p-6 shadow-sm"
            >
              <div class="flex items-center gap-3">
                <.icon name="hero-arrow-path" class="h-5 w-5 animate-spin text-teal-800" />
                <p class="font-serif text-xl font-semibold">Looking for useful starting points…</p>
              </div>
              <p class="mt-2 text-sm leading-6 text-slate-600">
                The suggestions will keep the limits you set while leaving room for more than one answer.
              </p>
            </div>

            <div
              :if={!@loading and @questions == []}
              class="mx-auto grid max-w-3xl gap-0 border border-stone-300 bg-white sm:grid-cols-[minmax(0,1fr)_12rem]"
            >
              <div class="p-6 sm:p-8">
                <p class="font-serif text-2xl font-semibold">No generated filler yet.</p>
                <p class="mt-3 text-sm leading-6 text-slate-600">
                  Move the controls to describe the territory, then ask for five questions. Selecting
                  one opens it directly in the new-grid form.
                </p>
              </div>
              <div class="hidden border-l border-stone-300 p-6 sm:block" aria-hidden="true">
                <div class="border-l-4 border-sky-500 bg-stone-50 px-3 py-2 text-xs font-semibold">
                  Question
                </div>
                <div class="ml-6 h-5 w-px bg-slate-400"></div>
                <div class="border-l-4 border-emerald-600 bg-stone-50 px-3 py-2 text-xs font-semibold">
                  Answer
                </div>
                <div class="ml-6 h-5 w-px bg-slate-400"></div>
                <div class="border-l-4 border-amber-500 bg-stone-50 px-3 py-2 text-xs font-semibold">
                  Follow-up
                </div>
              </div>
            </div>

            <div :if={!@loading and @questions != []} class="mx-auto max-w-3xl">
              <button
                :for={{question, index} <- Enum.with_index(@questions, 1)}
                type="button"
                class="group grid w-full grid-cols-[2.5rem_1fr_auto] items-start gap-3 border-b border-slate-300 bg-transparent py-5 text-left transition hover:border-teal-700 hover:bg-white focus:outline-none focus:ring-2 focus:ring-inset focus:ring-teal-700"
                phx-click={JS.push("select_question", value: %{question: question})}
              >
                <span class="pt-1 font-mono text-xs font-bold text-teal-800">
                  {index |> Integer.to_string() |> String.pad_leading(2, "0")}
                </span>
                <span class="font-serif text-xl font-semibold leading-7 text-slate-900">
                  {question}
                </span>
                <.icon
                  name="hero-arrow-right"
                  class="mt-1 h-5 w-5 text-slate-400 transition group-hover:translate-x-1 group-hover:text-teal-800"
                />
              </button>
            </div>
          </div>
        </main>
      </div>
    </div>
    """
  end

  attr :field, Phoenix.HTML.FormField, required: true
  attr :label, :string, required: true
  attr :value, :integer, required: true
  attr :left_label, :string, required: true
  attr :right_label, :string, required: true

  def slider(assigns) do
    ~H"""
    <div class="py-6">
      <div class="flex items-baseline justify-between gap-4">
        <label for={@field.id} class="text-sm font-semibold text-slate-900">{@label}</label>
        <span class="font-mono text-xs text-slate-500">{@value}</span>
      </div>
      <div class="relative mt-4 flex h-6 items-center">
        <div class="absolute h-1 w-full bg-stone-300"></div>
        <input
          type="range"
          id={@field.id}
          min="0"
          max="100"
          value={@value}
          name={@field.name}
          class="relative h-2 w-full cursor-pointer appearance-none bg-transparent focus:outline-none focus:ring-0 [&::-webkit-slider-thumb]:h-5 [&::-webkit-slider-thumb]:w-5 [&::-webkit-slider-thumb]:appearance-none [&::-webkit-slider-thumb]:rounded-sm [&::-webkit-slider-thumb]:border-2 [&::-webkit-slider-thumb]:border-slate-950 [&::-webkit-slider-thumb]:bg-teal-300 [&::-webkit-slider-thumb]:shadow-sm"
          phx-debounce="200"
        />
      </div>
      <div class="mt-1 flex justify-between text-[10px] font-semibold uppercase tracking-[0.14em] text-slate-500">
        <span>{@left_label}</span>
        <span>{@right_label}</span>
      </div>
    </div>
    """
  end
end
