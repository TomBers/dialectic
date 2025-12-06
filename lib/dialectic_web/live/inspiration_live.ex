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
    <div class="h-[calc(100vh-3.5rem)] overflow-hidden flex flex-col bg-white">
      <div class="flex-1 min-h-0 flex flex-col md:flex-row">
        <!-- Left Panel: Controls -->
        <div class="w-full md:w-2/5 flex flex-col bg-white border-r border-gray-200 overflow-y-auto z-10 shadow-lg md:shadow-none">
          <div class="p-6">
            <.header class="mb-8">
              Find Your Question
              <:subtitle>
                Adjust the sliders to discover questions that match your curiosity.
              </:subtitle>
            </.header>

            <form phx-change="update_preferences" class="space-y-8">
              <div class="space-y-6">
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
              </div>

              <div class="pt-4 sticky bottom-0 bg-white pb-4 border-t border-gray-100 mt-8">
                <button
                  type="button"
                  phx-click="generate_prompt"
                  class="w-full justify-center inline-flex items-center gap-2 rounded-full bg-gradient-to-r from-fuchsia-500 via-rose-500 to-amber-500 px-5 py-3 text-white text-lg font-semibold shadow-md hover:shadow-lg hover:opacity-95 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-rose-300 transition disabled:opacity-50 disabled:cursor-not-allowed"
                  disabled={@loading}
                >
                  {if @loading, do: "Generating...", else: "Generate Questions"}
                </button>
              </div>
            </form>
          </div>
        </div>
        
    <!-- Right Panel: Results -->
        <div class="flex-1 flex flex-col bg-gray-50 overflow-hidden relative">
          <div class="absolute inset-0 opacity-5 bg-[url('data:image/svg+xml,%3Csvg width=\'60\' height=\'60\' viewBox=\'0 0 60 60\' xmlns=\'http://www.w3.org/2000/svg\'%3E%3Cg fill=\'none\' fill-rule=\'evenodd\'%3E%3Cg fill=\'%23000000\' fill-opacity=\'1\'%3E%3Cpath d=\'M36 34v-4h-2v4h-4v2h4v4h2v-4h4v-2h-4zm0-30V0h-2v4h-4v2h4v4h2V6h4V4h-4zM6 34v-4H4v4H0v2h4v4h2v-4h4v-2H6zM6 4V0H4v4H0v2h4v4h2V6h4V4H6z\'/%3E%3C/g%3E%3C/g%3E%3C/svg%3E')]">
          </div>

          <div class="relative flex-1 overflow-y-auto p-6 md:p-12">
            <h3 class="text-2xl font-medium text-gray-900 mb-8 flex items-center gap-3">
              <.icon name="hero-sparkles" class="w-8 h-8 text-blue-500" /> Suggested Questions
            </h3>

            <div :if={@loading} class="flex flex-col items-center justify-center h-64 text-gray-500">
              <.icon name="hero-arrow-path" class="w-12 h-12 animate-spin text-blue-500 mb-4" />
              <p class="text-lg">Consulting the oracle...</p>
            </div>

            <div
              :if={!@loading and @questions == []}
              class="flex flex-col items-center justify-center h-64 text-gray-400"
            >
              <.icon name="hero-adjustments-horizontal" class="w-16 h-16 mb-4 opacity-50" />
              <p class="text-lg font-medium">Adjust preferences on the left and click Generate</p>
            </div>

            <div :if={!@loading and @questions != []} class="grid gap-4 max-w-3xl mx-auto">
              <div
                :for={question <- @questions}
                class="group relative bg-white p-6 rounded-xl border border-gray-200 shadow-sm hover:border-blue-300 hover:shadow-md transition-all cursor-pointer transform hover:-translate-y-1"
                phx-click={JS.push("select_question", value: %{question: question})}
              >
                <div class="flex justify-between items-start gap-4">
                  <p class="text-lg text-gray-800 font-medium leading-relaxed">{question}</p>
                  <div class="shrink-0 rounded-full bg-blue-50 p-2 text-blue-600 group-hover:bg-blue-100 transition-colors">
                    <.icon name="hero-arrow-right" class="w-5 h-5" />
                  </div>
                </div>
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
