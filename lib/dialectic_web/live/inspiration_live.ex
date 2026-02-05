defmodule DialecticWeb.InspirationLive do
  use DialecticWeb, :live_view

  alias Phoenix.LiveView.JS

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Question Inspiration")
     |> assign(:reality, 50)
     |> assign(:timeframe, 50)
     |> assign(:depth, 50)
     |> assign(:questions, [])
     |> assign(:loading, false)}
  end

  @impl true
  def handle_event("update_preferences", params, socket) do
    socket =
      socket
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
    <div class="h-[calc(100vh-2.5rem)] overflow-hidden flex flex-col bg-white">
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
                  left_label="Pure Fiction"
                  right_label="Reality-Grounded"
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
              <.icon name="hero-sparkles" class="w-8 h-8 text-blue-500" /> Your Generated Questions
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
    <div class="space-y-3 pt-2">
      <div class="flex justify-between items-end mb-2">
        <label for={@name} class="block text-base font-semibold text-gray-800 tracking-tight">
          {@label}
        </label>
      </div>
      <div class="relative h-6 flex items-center">
        <div class="absolute w-full h-2 bg-gradient-to-r from-gray-200 via-gray-300 to-gray-200 rounded-full">
        </div>
        <input
          type="range"
          id={@name}
          min="0"
          max="100"
          value={@value}
          name={@name}
          class="relative w-full h-2 appearance-none bg-transparent cursor-pointer [&::-webkit-slider-thumb]:appearance-none [&::-webkit-slider-thumb]:w-6 [&::-webkit-slider-thumb]:h-6 [&::-webkit-slider-thumb]:rounded-full [&::-webkit-slider-thumb]:bg-white [&::-webkit-slider-thumb]:border-2 [&::-webkit-slider-thumb]:border-indigo-600 [&::-webkit-slider-thumb]:shadow-md [&::-webkit-slider-thumb]:transition-transform [&::-webkit-slider-thumb]:hover:scale-110 focus:outline-none focus:ring-0"
          phx-debounce="200"
        />
      </div>
      <div class="flex justify-between text-xs font-medium text-gray-500 uppercase tracking-wider">
        <span>{@left_label}</span>
        <span>{@right_label}</span>
      </div>
    </div>
    """
  end
end
