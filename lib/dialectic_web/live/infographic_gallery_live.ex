defmodule DialecticWeb.InfographicGalleryLive do
  use DialecticWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    infographics = [
      %{
        id: "consciousness_in_ai",
        image_path: "/images/infographics/Consciousness_in_AI.jpg",
        title: "Consciousness in AI",
        graph_slug: "consciousness-in-ai",
        description: "Exploring the philosophical questions around AI consciousness"
      },
      %{
        id: "utopia",
        image_path: "/images/infographics/Utopia.jpg",
        title: "Utopia",
        graph_slug: "utopia",
        description: "An exploration of utopian ideals and their implications"
      },
      %{
        id: "collective_subconscious",
        image_path: "/images/infographics/collective_subconscious.jpg",
        title: "Collective Subconscious",
        graph_slug: "collective-subconscious",
        description: "Investigating the concept of shared unconscious knowledge"
      },
      %{
        id: "morality_of_ai_for_lesson_planning",
        image_path: "/images/infographics/morality_of_ai_for_lesson_planning.jpg",
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
          <button
            :for={infographic <- @infographics}
            type="button"
            class="group relative rounded-lg shadow-lg overflow-hidden transition-shadow duration-300 hover:shadow-2xl focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2 cursor-pointer aspect-[4/3]"
            phx-click="open_infographic"
            phx-value-id={infographic.id}
            role="button"
            tabindex="0"
            aria-label={"View #{infographic.title} infographic"}
          >
            <%!-- Image --%>
            <img
              src={infographic.image_path}
              alt={infographic.title}
              class="w-full h-full object-contain bg-gray-100 dark:bg-gray-900"
            />

            <%!-- Overlay --%>
            <div class="absolute inset-0 bg-gradient-to-t from-black/80 via-black/20 to-transparent opacity-0 group-hover:opacity-100 group-focus:opacity-100 transition-opacity duration-300 pointer-events-none">
              <div class="absolute bottom-0 left-0 right-0 p-6 text-white">
                <h3 class="text-xl font-semibold mb-2">
                  {infographic.title}
                </h3>
                <p class="text-white/90 text-sm mb-4">
                  {infographic.description}
                </p>
                <div class="flex items-center gap-4">
                  <span class="inline-flex items-center text-white font-medium text-sm pointer-events-auto">
                    <.link
                      navigate={~p"/g/#{infographic.graph_slug}"}
                      class="hover:text-blue-300"
                      tabindex="-1"
                    >
                      Explore Grid <.icon name="hero-arrow-right" class="w-4 h-4 ml-1 inline" />
                    </.link>
                  </span>
                  <span class="inline-flex items-center text-white/80 font-medium text-sm">
                    <.icon name="hero-magnifying-glass-plus" class="w-4 h-4 mr-1" />
                    <span>Click to zoom</span>
                  </span>
                </div>
              </div>
            </div>

            <%!-- Title badge always visible --%>
            <div class="absolute top-4 left-4 bg-white/95 dark:bg-gray-900/95 px-3 py-1.5 rounded-lg shadow-lg group-hover:opacity-0 group-focus:opacity-0 transition-opacity duration-300 pointer-events-none">
              <h3 class="text-sm font-semibold text-gray-900 dark:text-white">
                {infographic.title}
              </h3>
            </div>
          </button>
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
        class="fixed inset-0 z-[10001] overflow-y-auto"
        phx-mounted={JS.focus_first(to: "#infographic-modal-content")}
        phx-remove={JS.pop_focus()}
        phx-window-keydown="close_modal"
        phx-key="escape"
      >
        <%!-- Backdrop --%>
        <div
          class="fixed inset-0 bg-black bg-opacity-75 transition-opacity"
          phx-click="close_modal"
          aria-hidden="true"
        >
        </div>

        <%!-- Modal Content --%>
        <div class="flex min-h-screen items-start justify-center p-4 pt-12 sm:pt-14">
          <.focus_wrap id="infographic-modal-focus-wrap" class="w-full max-w-7xl">
            <div
              id="infographic-modal-content"
              class="relative w-full bg-white dark:bg-gray-800 rounded-lg shadow-2xl"
              role="dialog"
              aria-modal="true"
              aria-labelledby="infographic-modal-title"
              aria-describedby="infographic-modal-description"
              tabindex="-1"
            >
              <%!-- Close Button --%>
              <button
                type="button"
                phx-click="close_modal"
                aria-label="Close infographic zoom view"
                class="absolute top-4 right-4 z-10 p-2 rounded-full bg-gray-800 bg-opacity-50 hover:bg-opacity-75 text-white transition-all focus:outline-none focus:ring-2 focus:ring-white"
              >
                <.icon name="hero-x-mark" class="w-6 h-6" />
              </button>

              <%!-- Image --%>
              <div class="p-4">
                <img
                  src={@selected_infographic.image_path}
                  alt={@selected_infographic.title}
                  class="w-full h-auto rounded"
                />
              </div>

              <%!-- Info --%>
              <div class="p-6 border-t border-gray-200 dark:border-gray-700">
                <h2
                  id="infographic-modal-title"
                  class="text-2xl font-bold text-gray-900 dark:text-white mb-2"
                >
                  {@selected_infographic.title}
                </h2>
                <p id="infographic-modal-description" class="text-gray-600 dark:text-gray-300 mb-4">
                  {@selected_infographic.description}
                </p>
                <.link
                  navigate={~p"/g/#{@selected_infographic.graph_slug}"}
                  class="inline-flex items-center px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white font-medium rounded-lg transition-colors focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2"
                >
                  <span>Explore Interactive Grid</span>
                  <.icon name="hero-arrow-right" class="w-4 h-4 ml-2" />
                </.link>
              </div>
            </div>
          </.focus_wrap>
        </div>
      </div>
    <% end %>
    """
  end
end
