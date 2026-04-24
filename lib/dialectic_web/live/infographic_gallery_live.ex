defmodule DialecticWeb.InfographicGalleryLive do
  use DialecticWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    infographics = [
      %{
        id: "consciousness_in_ai",
        filename: "Consciousness_in_AI.jpg",
        title: "Consciousness in AI",
        graph_slug: "consciousness-in-ai",
        description: "Exploring the philosophical questions around AI consciousness"
      },
      %{
        id: "utopia",
        filename: "Utopia.jpg",
        title: "Utopia",
        graph_slug: "utopia",
        description: "An exploration of utopian ideals and their implications"
      },
      %{
        id: "collective_subconscious",
        filename: "collective_subconscious.jpg",
        title: "Collective Subconscious",
        graph_slug: "collective-subconscious",
        description: "Investigating the concept of shared unconscious knowledge"
      },
      %{
        id: "morality_of_ai_for_lesson_planning",
        filename: "morality_of_ai_for_lesson_planning.jpg",
        title: "Morality of AI for Lesson Planning",
        graph_slug: "morality-of-ai-for-lesson-planning",
        description: "Ethical considerations in using AI for educational planning"
      }
    ]

    {:ok,
     assign(socket,
       page_title: "Infographic Gallery",
       infographics: infographics,
       selected_infographic: nil
     )}
  end

  @impl true
  def handle_event("open_infographic", %{"id" => id}, socket) do
    selected = Enum.find(socket.assigns.infographics, fn i -> i.id == id end)
    {:noreply, assign(socket, selected_infographic: selected)}
  end

  @impl true
  def handle_event("close_modal", _params, socket) do
    {:noreply, assign(socket, selected_infographic: nil)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100 dark:from-gray-900 dark:to-gray-800 py-12 px-4 sm:px-6 lg:px-8">
        <div class="max-w-7xl mx-auto">
          <%!-- Header --%>
          <div class="text-center mb-12">
            <h1 class="text-4xl font-bold text-gray-900 dark:text-white mb-4">
              Infographic Gallery
            </h1>
            <p class="text-lg text-gray-600 dark:text-gray-300">
              Visual explorations of complex ideas through RationalGrid knowledge maps
            </p>
          </div>

          <%!-- Gallery Grid --%>
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-2 gap-8">
            <div
              :for={infographic <- @infographics}
              class="group relative rounded-lg shadow-lg overflow-hidden transition-shadow duration-300 hover:shadow-2xl cursor-pointer aspect-[4/3]"
              phx-click="open_infographic"
              phx-value-id={infographic.id}
            >
              <%!-- Image --%>
              <img
                src={~p"/images/infographics/#{infographic.filename}"}
                alt={infographic.title}
                class="w-full h-full object-contain bg-gray-100 dark:bg-gray-900"
              />

              <%!-- Overlay --%>
              <div class="absolute inset-0 bg-gradient-to-t from-black/80 via-black/20 to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-300">
                <div class="absolute bottom-0 left-0 right-0 p-6 text-white">
                  <h3 class="text-xl font-semibold mb-2">
                    {infographic.title}
                  </h3>
                  <p class="text-white/90 text-sm mb-4">
                    {infographic.description}
                  </p>
                  <div class="flex items-center gap-4">
                    <.link
                      navigate={~p"/g/#{infographic.graph_slug}"}
                      class="inline-flex items-center text-white hover:text-blue-300 font-medium text-sm"
                      phx-click={JS.exec("event.stopPropagation()")}
                    >
                      <span>Explore Grid</span>
                      <.icon name="hero-arrow-right" class="w-4 h-4 ml-1" />
                    </.link>
                    <span class="inline-flex items-center text-white/80 font-medium text-sm">
                      <.icon name="hero-magnifying-glass-plus" class="w-4 h-4 mr-1" />
                      <span>Click to zoom</span>
                    </span>
                  </div>
                </div>
              </div>

              <%!-- Title badge always visible --%>
              <div class="absolute top-4 left-4 bg-white/95 dark:bg-gray-900/95 px-3 py-1.5 rounded-lg shadow-lg group-hover:opacity-0 transition-opacity duration-300">
                <h3 class="text-sm font-semibold text-gray-900 dark:text-white">
                  {infographic.title}
                </h3>
              </div>
            </div>
          </div>

          <%!-- Back to Home --%>
          <div class="text-center mt-12">
            <.link
              navigate={~p"/"}
              class="inline-flex items-center text-blue-600 dark:text-blue-400 hover:text-blue-800 dark:hover:text-blue-300 font-medium"
            >
              <.icon name="hero-arrow-left" class="w-4 h-4 mr-2" />
              <span>Back to Home</span>
            </.link>
          </div>
        </div>
      </div>

      <%!-- Zoom Modal --%>
      <%= if @selected_infographic do %>
        <div
          id="infographic-modal"
          class="fixed inset-0 z-50 overflow-y-auto"
          phx-click="close_modal"
          phx-window-keydown="close_modal"
          phx-key="escape"
        >
          <%!-- Backdrop --%>
          <div class="fixed inset-0 bg-black bg-opacity-75 transition-opacity"></div>

          <%!-- Modal Content --%>
          <div class="flex min-h-screen items-center justify-center p-4">
            <div
              class="relative max-w-7xl w-full bg-white dark:bg-gray-800 rounded-lg shadow-2xl"
              phx-click={JS.exec("event.stopPropagation()")}
            >
              <%!-- Close Button --%>
              <button
                type="button"
                phx-click="close_modal"
                class="absolute top-4 right-4 z-10 p-2 rounded-full bg-gray-800 bg-opacity-50 hover:bg-opacity-75 text-white transition-all"
              >
                <.icon name="hero-x-mark" class="w-6 h-6" />
              </button>

              <%!-- Image --%>
              <div class="p-4">
                <img
                  src={~p"/images/infographics/#{@selected_infographic.filename}"}
                  alt={@selected_infographic.title}
                  class="w-full h-auto rounded"
                />
              </div>

              <%!-- Info --%>
              <div class="p-6 border-t border-gray-200 dark:border-gray-700">
                <h2 class="text-2xl font-bold text-gray-900 dark:text-white mb-2">
                  {@selected_infographic.title}
                </h2>
                <p class="text-gray-600 dark:text-gray-300 mb-4">
                  {@selected_infographic.description}
                </p>
                <.link
                  navigate={~p"/g/#{@selected_infographic.graph_slug}"}
                  class="inline-flex items-center px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white font-medium rounded-lg transition-colors"
                >
                  <span>Explore Interactive Grid</span>
                  <.icon name="hero-arrow-right" class="w-4 h-4 ml-2" />
                </.link>
              </div>
            </div>
          </div>
        </div>
      <% end %>
    """
  end
end
