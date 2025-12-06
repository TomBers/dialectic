defmodule DialecticWeb.InspirationLive do
  use DialecticWeb, :live_view

  alias Phoenix.LiveView.JS

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Question Inspiration")
     |> assign(:reality, 50)
     |> assign(:focus, 50)
     |> assign(:timeframe, 50)
     |> assign(:depth, 50)
     |> assign(:tone, 50)
     |> assign(:questions, [])
     |> assign(:loading, false)}
  end

  @impl true
  def handle_event("update_preferences", params, socket) do
    socket =
      socket
      |> assign(:reality, String.to_integer(params["reality"]))
      |> assign(:focus, String.to_integer(params["focus"]))
      |> assign(:timeframe, String.to_integer(params["timeframe"]))
      |> assign(:depth, String.to_integer(params["depth"]))
      |> assign(:tone, String.to_integer(params["tone"]))

    {:noreply, socket}
  end

  def handle_event("generate_prompt", _, socket) do
    prompt = build_prompt(socket.assigns)

    Task.async(fn ->
      Dialectic.Inspiration.Generator.generate_questions(prompt)
    end)

    {:noreply, assign(socket, loading: true, questions: [])}
  end

  def handle_event("select_question", %{"question" => question}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/start/new/idea?initial_prompt=#{question}")}
  end

  def handle_info({ref, result}, socket) do
    Process.demonitor(ref, [:flush])

    socket =
      case result do
        {:ok, questions} ->
          assign(socket, loading: false, questions: questions)

        {:error, _} ->
          put_flash(socket, :error, "Failed to generate questions. Please try again.")
          |> assign(loading: false)
      end

    {:noreply, socket}
  end

  def handle_info({:DOWN, _ref, :process, _pid, _reason}, socket) do
    {:noreply, assign(socket, loading: false)}
  end

  defp build_prompt(assigns) do
    """
    Act as a muse and generate 5 thought-provoking questions for exploration.

    Adhere to these stylistic and thematic preferences:
    - Reality: #{describe_scale(assigns.reality, "Pure Fiction", "Strictly Non-Fiction")}
    - Focus: #{describe_scale(assigns.focus, "Mainstream/Popular", "Esoteric/Niche")}
    - Timeframe: #{describe_scale(assigns.timeframe, "The Past", "The Future")}
    - Depth: #{describe_scale(assigns.depth, "Beginner/General Audience", "Expert/Technical")}
    - Tone: #{describe_scale(assigns.tone, "Serious/Academic", "Playful/Whimsical")}

    Output ONLY the questions as a numbered list.
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
    <div class="max-w-4xl mx-auto py-12 px-4 sm:px-6 lg:px-8">
      <.header class="text-center mb-12">
        Find Your Question
        <:subtitle>
          Adjust the sliders to discover questions that match your curiosity.
        </:subtitle>
      </.header>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-12">
        <div class="space-y-8 bg-zinc-50 p-6 rounded-lg shadow-sm h-fit">
          <h3 class="text-lg font-medium text-zinc-900 border-b border-zinc-200 pb-2">
            Preferences
          </h3>

          <form phx-change="update_preferences" class="space-y-6">
            <.slider
              label="Reality"
              name="reality"
              value={@reality}
              left_label="Fiction"
              right_label="Non-Fiction"
            />

            <.slider
              label="Focus"
              name="focus"
              value={@focus}
              left_label="Mainstream"
              right_label="Esoteric"
            />

            <.slider
              label="Timeframe"
              name="timeframe"
              value={@timeframe}
              left_label="Past"
              right_label="Future"
            />

            <.slider
              label="Depth"
              name="depth"
              value={@depth}
              left_label="Beginner"
              right_label="Expert"
            />

            <.slider
              label="Tone"
              name="tone"
              value={@tone}
              left_label="Serious"
              right_label="Playful"
            />

            <div class="pt-4">
              <.button type="button" phx-click="generate_prompt" class="w-full" disabled={@loading}>
                {if @loading, do: "Generating...", else: "Generate Questions"}
              </.button>
            </div>
          </form>
        </div>

        <div class="space-y-6">
          <h3 class="text-lg font-medium text-zinc-900 border-b border-zinc-200 pb-2">
            Suggested Questions
          </h3>

          <div :if={@loading} class="text-center py-12">
            <.icon name="hero-arrow-path" class="w-8 h-8 animate-spin text-zinc-400 mx-auto" />
            <p class="mt-2 text-sm text-zinc-500">Consulting the oracle...</p>
          </div>

          <div :if={!@loading and @questions == []} class="text-zinc-500 italic text-center py-12">
            Adjust preferences and click Generate Questions
          </div>

          <div :if={!@loading and @questions != []} class="space-y-4">
            <div
              :for={question <- @questions}
              class="group relative bg-white p-4 rounded-lg border border-zinc-200 shadow-sm hover:border-zinc-400 hover:shadow-md transition-all cursor-pointer"
              phx-click={JS.push("select_question", value: %{question: question})}
            >
              <div class="flex justify-between items-start gap-4">
                <p class="text-zinc-700 font-medium">{question}</p>
                <.icon
                  name="hero-chevron-right"
                  class="w-5 h-5 text-zinc-300 group-hover:text-zinc-600 mt-1"
                />
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :name, :string, required: true
  attr :value, :integer, required: true
  attr :left_label, :string, required: true
  attr :right_label, :string, required: true

  def slider(assigns) do
    ~H"""
    <div class="space-y-2">
      <div class="flex justify-between items-end mb-1">
        <label class="block text-sm font-medium leading-6 text-zinc-900">
          {@label}
        </label>
      </div>
      <div class="relative">
        <input
          type="range"
          min="0"
          max="100"
          value={@value}
          name={@name}
          class="w-full h-2 bg-zinc-200 rounded-lg appearance-none cursor-pointer accent-zinc-900 focus:outline-none focus:ring-2 focus:ring-zinc-500"
          phx-debounce="200"
        />
      </div>
      <div class="flex justify-between text-xs font-medium text-zinc-500">
        <span>{@left_label}</span>
        <span>{@right_label}</span>
      </div>
    </div>
    """
  end
end
