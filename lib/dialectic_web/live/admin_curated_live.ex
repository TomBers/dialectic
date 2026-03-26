defmodule DialecticWeb.AdminCuratedLive do
  use DialecticWeb, :live_view

  alias Dialectic.DbActions.Graphs

  @sections ["curated", "featured"]

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user

    unless current_user && current_user.is_admin do
      {:ok,
       socket
       |> put_flash(:error, "Access denied.")
       |> redirect(to: ~p"/")}
    else
      curated = load_section("curated")
      featured = load_section("featured")

      {:ok,
       assign(socket,
         page_title: "Manage Curated Grids",
         curated: curated,
         featured: featured,
         search_term: "",
         search_results: [],
         add_section: "curated",
         add_note: ""
       )}
    end
  end

  @impl true
  def handle_event("search_graphs", %{"search" => term}, socket) do
    results =
      if String.trim(term) == "" do
        []
      else
        Graphs.all_graphs_with_notes(term, limit: 20)
      end

    {:noreply, assign(socket, search_term: term, search_results: results)}
  end

  @impl true
  def handle_event("add_curated", %{"title" => title, "section" => section}, socket) do
    current_user = socket.assigns.current_user

    case Graphs.add_curated_grid(%{
           graph_title: title,
           curator_id: current_user.id,
           section: section,
           note: socket.assigns.add_note
         }) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Added \"#{title}\" to #{section} section.")
         |> assign(
           curated: load_section("curated"),
           featured: load_section("featured"),
           search_results: [],
           search_term: "",
           add_note: ""
         )}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to add grid.")}
    end
  end

  @impl true
  def handle_event("remove_curated", %{"title" => title, "section" => section}, socket) do
    Graphs.remove_curated_grid(title, section)

    {:noreply,
     socket
     |> put_flash(:info, "Removed \"#{title}\" from #{section}.")
     |> assign(
       curated: load_section("curated"),
       featured: load_section("featured")
     )}
  end

  @impl true
  def handle_event("set_section", %{"section" => section}, socket) when section in @sections do
    {:noreply, assign(socket, add_section: section)}
  end

  @impl true
  def handle_event("update_note", %{"note" => note}, socket) do
    {:noreply, assign(socket, add_note: note)}
  end

  defp load_section(section) do
    Graphs.list_curated_grids(section, 20)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-5xl px-6 py-10">
      <h1 class="text-2xl font-bold text-gray-900 mb-2">Manage Curated Grids</h1>
      <p class="text-sm text-gray-500 mb-8">
        Add or remove grids from the curated and featured sections on the home page.
      </p>

      <%!-- Search and Add --%>
      <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-6 mb-8">
        <h2 class="text-lg font-semibold text-gray-900 mb-4">Add a Grid</h2>

        <div class="space-y-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Search for a grid</label>
            <form
              id="curated-search-form"
              phx-change="search_graphs"
              phx-submit="search_graphs"
              class="flex gap-2"
            >
              <input
                type="text"
                name="search"
                value={@search_term}
                placeholder="Search by title..."
                phx-debounce="300"
                class="flex-1 rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500"
                autocomplete="off"
              />
            </form>
          </div>

          <div class="flex items-center gap-4">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Section</label>
              <div class="flex gap-2">
                <%= for section <- ["curated", "featured"] do %>
                  <button
                    type="button"
                    phx-click="set_section"
                    phx-value-section={section}
                    class={[
                      "px-3 py-1.5 rounded-lg text-sm font-medium transition-colors",
                      if(@add_section == section,
                        do: "bg-indigo-600 text-white",
                        else: "bg-gray-100 text-gray-700 hover:bg-gray-200"
                      )
                    ]}
                  >
                    {String.capitalize(section)}
                  </button>
                <% end %>
              </div>
            </div>

            <div class="flex-1">
              <label class="block text-sm font-medium text-gray-700 mb-1">Note (optional)</label>
              <form id="curated-note-form" phx-change="update_note">
                <input
                  type="text"
                  name="note"
                  value={@add_note}
                  placeholder="Why this grid is notable..."
                  phx-debounce="300"
                  class="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500"
                />
              </form>
            </div>
          </div>

          <%= if @search_results != [] do %>
            <div class="border border-gray-200 rounded-lg divide-y divide-gray-100 max-h-64 overflow-y-auto">
              <%= for {g, _count} <- @search_results do %>
                <div class="flex items-center justify-between p-3 hover:bg-gray-50">
                  <div>
                    <p class="text-sm font-medium text-gray-900">{g.title}</p>
                    <div class="flex gap-1 mt-1">
                      <%= for tag <- (g.tags || []) do %>
                        <span class="text-xs bg-gray-100 text-gray-600 px-1.5 py-0.5 rounded">
                          {tag}
                        </span>
                      <% end %>
                    </div>
                  </div>
                  <button
                    type="button"
                    phx-click="add_curated"
                    phx-value-title={g.title}
                    phx-value-section={@add_section}
                    class="inline-flex items-center gap-1 rounded-lg bg-indigo-600 px-3 py-1.5 text-xs font-semibold text-white hover:bg-indigo-500 transition"
                  >
                    <.icon name="hero-plus" class="w-3.5 h-3.5" /> Add to {@add_section}
                  </button>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>
      </div>

      <%!-- Curated Section --%>
      <div class="mb-8">
        <h2 class="text-lg font-semibold text-gray-900 mb-4 flex items-center gap-2">
          <.icon name="hero-star" class="w-5 h-5 text-amber-500" /> Curated Grids
          <span class="text-sm font-normal text-gray-500">({length(@curated)})</span>
        </h2>

        <%= if @curated == [] do %>
          <p class="text-sm text-gray-500 italic">No curated grids yet.</p>
        <% else %>
          <div class="space-y-2">
            <%= for item <- @curated do %>
              <div class="flex items-center justify-between rounded-lg border border-gray-200 bg-white p-3 shadow-sm">
                <div>
                  <p class="text-sm font-medium text-gray-900">{item.graph.title}</p>
                  <p class="text-xs text-gray-500">
                    <%= if item.author_name do %>
                      by {item.author_name}
                    <% end %>
                    <%= if item.note && item.note != "" do %>
                      — {item.note}
                    <% end %>
                  </p>
                </div>
                <button
                  type="button"
                  phx-click="remove_curated"
                  phx-value-title={item.graph.title}
                  phx-value-section="curated"
                  class="inline-flex items-center gap-1 rounded-lg bg-red-50 px-3 py-1.5 text-xs font-semibold text-red-700 hover:bg-red-100 transition"
                >
                  <.icon name="hero-trash" class="w-3.5 h-3.5" /> Remove
                </button>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>

      <%!-- Featured Section --%>
      <div class="mb-8">
        <h2 class="text-lg font-semibold text-gray-900 mb-4 flex items-center gap-2">
          <.icon name="hero-users" class="w-5 h-5 text-indigo-500" /> Featured by Partners
          <span class="text-sm font-normal text-gray-500">({length(@featured)})</span>
        </h2>

        <%= if @featured == [] do %>
          <p class="text-sm text-gray-500 italic">No featured grids yet.</p>
        <% else %>
          <div class="space-y-2">
            <%= for item <- @featured do %>
              <div class="flex items-center justify-between rounded-lg border border-gray-200 bg-white p-3 shadow-sm">
                <div>
                  <p class="text-sm font-medium text-gray-900">{item.graph.title}</p>
                  <p class="text-xs text-gray-500">
                    <%= if item.author_name do %>
                      by {item.author_name}
                    <% end %>
                    <%= if item.note && item.note != "" do %>
                      — {item.note}
                    <% end %>
                  </p>
                </div>
                <button
                  type="button"
                  phx-click="remove_curated"
                  phx-value-title={item.graph.title}
                  phx-value-section="featured"
                  class="inline-flex items-center gap-1 rounded-lg bg-red-50 px-3 py-1.5 text-xs font-semibold text-red-700 hover:bg-red-100 transition"
                >
                  <.icon name="hero-trash" class="w-3.5 h-3.5" /> Remove
                </button>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>

      <.link
        navigate={~p"/"}
        class="inline-flex items-center gap-2 text-sm font-semibold text-indigo-600 hover:text-indigo-500 transition"
      >
        <.icon name="hero-arrow-left" class="h-4 w-4" /> Back to home
      </.link>
    </div>
    """
  end
end
