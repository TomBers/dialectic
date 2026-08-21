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
        description: "Questions around machine consciousness."
      },
      %{
        id: "utopia",
        image_path: "/images/infographics/Utopia.jpg",
        title: "Utopia",
        graph_slug: "utopia",
        description: "Utopian ideals and their consequences."
      },
      %{
        id: "collective_subconscious",
        image_path: "/images/infographics/collective_subconscious.jpg",
        title: "Collective Subconscious",
        graph_slug: "collective-subconscious",
        description: "Shared unconscious knowledge."
      },
      %{
        id: "morality_of_ai_for_lesson_planning",
        image_path: "/images/infographics/morality_of_ai_for_lesson_planning.jpg",
        title: "Morality of AI for Lesson Planning",
        graph_slug: "morality-of-ai-for-lesson-planning",
        description: "Ethics of AI-assisted lesson planning."
      }
    ]

    {:ok,
     assign(socket,
       page_title: "Infographic Gallery",
       contact_mailto: "mailto:hello@rationalgrid.ai?subject=Infographic%20request",
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
    <div class="min-h-screen bg-[#f4f1e9] text-slate-950">
      <header class="border-b border-stone-300 bg-white">
        <div class="mx-auto grid max-w-7xl gap-6 px-5 py-12 sm:px-8 sm:py-16 lg:grid-cols-[minmax(0,1fr)_18rem] lg:items-end lg:px-10">
          <div class="max-w-4xl">
            <p class="border-l-2 border-teal-700 pl-3 text-xs font-semibold uppercase tracking-[0.2em] text-teal-800">
              From public grids
            </p>
            <h1 class="mt-5 font-serif text-5xl font-semibold tracking-tight sm:text-6xl">
              Infographic Gallery
            </h1>
            <p class="mt-4 max-w-2xl text-lg leading-8 text-slate-600">
              Complex ideas, drawn from RationalGrid maps.
            </p>
          </div>
          <p class="border-t border-slate-300 pt-4 text-sm leading-6 text-slate-600">
            Open an image, or follow its source grid.
          </p>
        </div>
      </header>

      <main class="mx-auto max-w-7xl px-5 py-10 sm:px-8 sm:py-14 lg:px-10">
        <div id="infographic-gallery-list" class="grid gap-x-8 gap-y-12 md:grid-cols-2">
          <article :for={{infographic, index} <- Enum.with_index(@infographics, 1)}>
            <button
              type="button"
              class="group block w-full border border-stone-300 bg-white p-2 text-left shadow-sm transition hover:border-slate-500 focus:outline-none focus:ring-2 focus:ring-teal-700 focus:ring-offset-4 focus:ring-offset-[#f4f1e9]"
              phx-click="open_infographic"
              phx-value-id={infographic.id}
              aria-label={"View #{infographic.title} infographic"}
            >
              <img
                src={infographic.image_path}
                alt={infographic.title}
                class="aspect-[4/3] w-full bg-stone-100 object-contain"
              />
            </button>
            <div class="mt-4 grid grid-cols-[2.5rem_1fr] gap-3 border-t border-slate-400 pt-3">
              <span class="font-mono text-xs font-bold text-teal-800">
                {index |> Integer.to_string() |> String.pad_leading(2, "0")}
              </span>
              <div>
                <h2 class="font-serif text-2xl font-semibold tracking-tight">
                  {infographic.title}
                </h2>
                <p class="mt-2 text-sm leading-6 text-slate-600">{infographic.description}</p>
                <div class="mt-3 flex flex-wrap gap-4 text-sm font-semibold">
                  <button
                    type="button"
                    phx-click={JS.push("open_infographic", value: %{id: infographic.id})}
                    class="border-b border-slate-500 pb-0.5 text-slate-900 transition hover:border-teal-700 hover:text-teal-800"
                  >
                    View full size
                  </button>
                  <.link
                    navigate={~p"/g/#{infographic.graph_slug}"}
                    class="inline-flex items-center gap-1 border-b border-slate-500 pb-0.5 text-slate-900 transition hover:border-teal-700 hover:text-teal-800"
                  >
                    Explore grid <.icon name="hero-arrow-right" class="h-4 w-4" />
                  </.link>
                </div>
              </div>
            </div>
          </article>
        </div>

        <section
          id="gallery-infographic-cta"
          class="mt-14 grid gap-6 border border-slate-700 bg-slate-950 p-6 text-white sm:grid-cols-[minmax(0,1fr)_auto] sm:items-center sm:p-8"
        >
          <div>
            <p class="text-xs font-semibold uppercase tracking-[0.2em] text-teal-300">
              Request an infographic
            </p>
            <h2 class="mt-2 font-serif text-3xl font-semibold">
              Turn a grid into a visual.
            </h2>
            <p class="mt-2 max-w-2xl text-sm leading-6 text-slate-300">
              Contact us about a shareable infographic.
            </p>
          </div>
          <a
            href={@contact_mailto}
            id="gallery-infographic-contact-link"
            class="inline-flex items-center justify-center gap-2 rounded-md bg-teal-300 px-4 py-2.5 text-sm font-semibold text-slate-950 transition hover:bg-teal-200"
          >
            Contact us <.icon name="hero-arrow-right" class="h-4 w-4" />
          </a>
        </section>

        <div class="mt-10">
          <.link
            navigate={~p"/"}
            class="inline-flex items-center gap-2 border-b border-slate-500 pb-1 text-sm font-semibold text-slate-800 transition hover:border-teal-700 hover:text-teal-800"
          >
            <.icon name="hero-arrow-left" class="h-4 w-4" /> Back to home
          </.link>
        </div>
      </main>
    </div>

    <%= if @selected_infographic do %>
      <div
        id="infographic-modal"
        class="fixed inset-0 z-[10001] overflow-y-auto"
        phx-mounted={JS.focus_first(to: "#infographic-modal-content")}
        phx-remove={JS.pop_focus()}
        phx-window-keydown="close_modal"
        phx-key="escape"
      >
        <div
          id="infographic-modal-backdrop"
          class="fixed inset-0 bg-slate-950/90"
          phx-click="close_modal"
          aria-hidden="true"
        >
        </div>

        <div class="relative flex min-h-screen items-start justify-center p-4 pt-12 sm:pt-16">
          <.focus_wrap id="infographic-modal-focus-wrap" class="w-full max-w-7xl">
            <div
              id="infographic-modal-content"
              class="relative w-full border border-slate-700 bg-white shadow-2xl"
              role="dialog"
              aria-modal="true"
              aria-labelledby="infographic-modal-title"
              aria-describedby="infographic-modal-description"
              tabindex="-1"
            >
              <button
                type="button"
                phx-click="close_modal"
                aria-label="Close infographic zoom view"
                class="absolute right-3 top-3 z-10 inline-flex h-10 w-10 items-center justify-center rounded-md bg-slate-950 text-white shadow-lg transition hover:bg-slate-800 focus:outline-none focus:ring-2 focus:ring-teal-300"
              >
                <.icon name="hero-x-mark" class="h-5 w-5" />
              </button>

              <div class="bg-stone-100 p-3 sm:p-5">
                <img
                  src={@selected_infographic.image_path}
                  alt={@selected_infographic.title}
                  class="mx-auto h-auto w-full"
                />
              </div>

              <div class="grid gap-5 border-t border-stone-300 p-5 sm:grid-cols-[minmax(0,1fr)_auto] sm:items-end sm:p-6">
                <div>
                  <h2
                    id="infographic-modal-title"
                    class="font-serif text-3xl font-semibold text-slate-950"
                  >
                    {@selected_infographic.title}
                  </h2>
                  <p id="infographic-modal-description" class="mt-2 text-sm leading-6 text-slate-600">
                    {@selected_infographic.description}
                  </p>
                </div>
                <.link
                  navigate={~p"/g/#{@selected_infographic.graph_slug}"}
                  class="inline-flex items-center justify-center gap-2 rounded-md bg-slate-950 px-4 py-2.5 text-sm font-semibold text-white transition hover:bg-slate-800"
                >
                  Explore grid <.icon name="hero-arrow-right" class="h-4 w-4" />
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
