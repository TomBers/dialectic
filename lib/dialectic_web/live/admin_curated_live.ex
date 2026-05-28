defmodule DialecticWeb.AdminCuratedLive do
  use DialecticWeb, :live_view

  alias Dialectic.DbActions.Graphs
  alias Dialectic.Highlights

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
      deleted_grids = Graphs.list_deleted_graphs(50)
      quote_highlights = Highlights.list_curated_quote_highlights(50)

      {:ok,
       assign(socket,
         page_title: "Manage Homepage Curation",
         curated: curated,
         featured: featured,
         deleted_grids: deleted_grids,
         quote_highlights: quote_highlights,
         quote_search_term: "",
         quote_search_results: [],
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
  def handle_event("search_quote_highlights", %{"search" => term}, socket) do
    results =
      if String.trim(term) == "" do
        []
      else
        Highlights.list_quote_highlight_candidates(term, 30)
      end

    {:noreply, assign(socket, quote_search_term: term, quote_search_results: results)}
  end

  @impl true
  def handle_event("add_quote_highlight", %{"highlight_id" => highlight_id}, socket) do
    current_user = socket.assigns.current_user

    case Highlights.add_curated_quote_highlight(%{
           highlight_id: highlight_id,
           curator_id: current_user.id
         }) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Added highlight to quote pool.")
         |> reload_quote_highlights()}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to add highlight to quote pool.")}
    end
  end

  @impl true
  def handle_event("remove_quote_highlight", %{"highlight_id" => highlight_id}, socket) do
    Highlights.remove_curated_quote_highlight(highlight_id)

    {:noreply,
     socket
     |> put_flash(:info, "Removed highlight from quote pool.")
     |> reload_quote_highlights()}
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

  @impl true
  def handle_event("soft_delete", %{"title" => title}, socket) do
    case Graphs.soft_delete_graph(title) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Hidden \"#{title}\" from homepage.")
         |> assign(
           deleted_grids: Graphs.list_deleted_graphs(50),
           curated: load_section("curated"),
           featured: load_section("featured"),
           search_results: [],
           search_term: ""
         )}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to hide grid.")}
    end
  end

  @impl true
  def handle_event("restore_graph", %{"title" => title}, socket) do
    case Graphs.restore_graph(title) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Restored \"#{title}\" to homepage.")
         |> assign(
           deleted_grids: Graphs.list_deleted_graphs(50),
           curated: load_section("curated"),
           featured: load_section("featured")
         )}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to restore grid.")}
    end
  end

  defp load_section(section) do
    Graphs.list_curated_grids(section, 20)
  end

  defp reload_quote_highlights(socket) do
    term = socket.assigns.quote_search_term

    search_results =
      if String.trim(term) == "" do
        []
      else
        Highlights.list_quote_highlight_candidates(term, 30)
      end

    assign(socket,
      quote_highlights: Highlights.list_curated_quote_highlights(50),
      quote_search_results: search_results
    )
  end

  defp quote_preview(text) do
    (text || "")
    |> String.trim()
    |> String.slice(0, 220)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-5xl px-6 py-10">
      <h1 class="text-2xl font-bold text-gray-900 mb-2">Manage Homepage Curation</h1>
      <p class="text-sm text-gray-500 mb-4">
        Add or remove quote highlights, editor picks, and partner grids on the home page.
      </p>

      <.link
        navigate={~p"/admin/graphs/import"}
        class="mb-8 inline-flex items-center gap-2 rounded-lg bg-indigo-600 px-4 py-2 text-sm font-semibold text-white hover:bg-indigo-500 transition"
      >
        <.icon name="hero-arrow-up-tray" class="h-4 w-4" /> Import graph JSON
      </.link>

      <%!-- Quote Highlights --%>
      <div class="rounded-xl border border-indigo-200 bg-indigo-50/40 shadow-sm p-6 mb-8">
        <div class="mb-4 flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <h2 class="text-lg font-semibold text-gray-900 flex items-center gap-2">
              <.icon name="hero-sparkles" class="w-5 h-5 text-indigo-500" /> Quote of the Day Pool
              <span class="text-sm font-normal text-gray-500">({length(@quote_highlights)})</span>
            </h2>
            <p class="mt-1 text-sm text-gray-500">
              Select the exact highlights the homepage quote can rotate through.
            </p>
          </div>
        </div>

        <div class="space-y-4">
          <form
            id="quote-highlight-search-form"
            phx-change="search_quote_highlights"
            phx-submit="search_quote_highlights"
          >
            <label class="block text-sm font-medium text-gray-700 mb-1">
              Search highlights by quote text or grid title
            </label>
            <input
              type="text"
              name="search"
              value={@quote_search_term}
              placeholder="Search highlights..."
              phx-debounce="300"
              class="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500"
              autocomplete="off"
            />
          </form>

          <%= if @quote_search_results != [] do %>
            <div class="border border-indigo-100 rounded-lg divide-y divide-indigo-100 max-h-80 overflow-y-auto bg-white">
              <%= for item <- @quote_search_results do %>
                <div class="flex flex-col gap-3 p-3 hover:bg-indigo-50/40 sm:flex-row sm:items-start sm:justify-between">
                  <div class="min-w-0">
                    <p class="text-sm font-medium leading-6 text-gray-900">
                      “{quote_preview(item.highlight.selected_text_snapshot)}”
                    </p>
                    <p class="mt-1 text-xs text-gray-500">
                      {item.graph.title}
                      <%= if item.author_name do %>
                        · by {item.author_name}
                      <% end %>
                    </p>
                  </div>

                  <%= if item.curated_highlight_id do %>
                    <span class="inline-flex shrink-0 items-center gap-1 rounded-lg bg-green-50 px-3 py-1.5 text-xs font-semibold text-green-700 ring-1 ring-green-200">
                      <.icon name="hero-check" class="w-3.5 h-3.5" /> In pool
                    </span>
                  <% else %>
                    <button
                      type="button"
                      phx-click="add_quote_highlight"
                      phx-value-highlight_id={item.highlight.id}
                      class="inline-flex shrink-0 items-center gap-1 rounded-lg bg-indigo-600 px-3 py-1.5 text-xs font-semibold text-white hover:bg-indigo-500 transition"
                    >
                      <.icon name="hero-plus" class="w-3.5 h-3.5" /> Add quote
                    </button>
                  <% end %>
                </div>
              <% end %>
            </div>
          <% end %>

          <%= if @quote_highlights == [] do %>
            <p class="text-sm text-gray-500 italic">No curated quote highlights yet.</p>
          <% else %>
            <div class="space-y-2">
              <%= for item <- @quote_highlights do %>
                <div class="flex flex-col gap-3 rounded-lg border border-gray-200 bg-white p-3 shadow-sm sm:flex-row sm:items-start sm:justify-between">
                  <div class="min-w-0">
                    <p class="text-sm font-medium leading-6 text-gray-900">
                      “{quote_preview(item.highlight.selected_text_snapshot)}”
                    </p>
                    <p class="mt-1 text-xs text-gray-500">
                      {item.graph.title}
                      <%= if item.author_name do %>
                        · by {item.author_name}
                      <% end %>
                    </p>
                  </div>
                  <div class="flex shrink-0 gap-2">
                    <.link
                      navigate={graph_path(item.graph, item.highlight.node_id)}
                      class="inline-flex items-center gap-1 rounded-lg bg-gray-50 px-3 py-1.5 text-xs font-semibold text-gray-700 hover:bg-gray-100 transition"
                    >
                      <.icon name="hero-arrow-top-right-on-square" class="w-3.5 h-3.5" /> Open
                    </.link>
                    <button
                      type="button"
                      phx-click="remove_quote_highlight"
                      phx-value-highlight_id={item.highlight.id}
                      class="inline-flex items-center gap-1 rounded-lg bg-red-50 px-3 py-1.5 text-xs font-semibold text-red-700 hover:bg-red-100 transition"
                    >
                      <.icon name="hero-trash" class="w-3.5 h-3.5" /> Remove
                    </button>
                  </div>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>
      </div>

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
              <%= for {g, _count, _author} <- @search_results do %>
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
                  <div class="flex gap-2">
                    <button
                      type="button"
                      phx-click="add_curated"
                      phx-value-title={g.title}
                      phx-value-section={@add_section}
                      class="inline-flex items-center gap-1 rounded-lg bg-indigo-600 px-3 py-1.5 text-xs font-semibold text-white hover:bg-indigo-500 transition"
                    >
                      <.icon name="hero-plus" class="w-3.5 h-3.5" /> Add to {@add_section}
                    </button>
                    <button
                      type="button"
                      phx-click="soft_delete"
                      phx-value-title={g.title}
                      class="inline-flex items-center gap-1 rounded-lg bg-red-50 px-3 py-1.5 text-xs font-semibold text-red-700 hover:bg-red-100 transition"
                    >
                      <.icon name="hero-eye-slash" class="w-3.5 h-3.5" /> Hide
                    </button>
                  </div>
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

      <%!-- Hidden Grids Section --%>
      <div class="mb-8">
        <h2 class="text-lg font-semibold text-gray-900 mb-4 flex items-center gap-2">
          <.icon name="hero-eye-slash" class="w-5 h-5 text-red-500" /> Hidden from Homepage
          <span class="text-sm font-normal text-gray-500">({length(@deleted_grids)})</span>
        </h2>

        <p class="text-sm text-gray-500 mb-4">
          These grids are hidden from normal discovery and can be restored from this page.
        </p>

        <%= if @deleted_grids == [] do %>
          <p class="text-sm text-gray-500 italic">No hidden grids.</p>
        <% else %>
          <div class="space-y-2">
            <%= for {graph, author_name} <- @deleted_grids do %>
              <div class="flex items-center justify-between rounded-lg border border-red-200 bg-red-50 p-3 shadow-sm">
                <div>
                  <p class="text-sm font-medium text-gray-900">{graph.title}</p>
                  <p class="text-xs text-gray-500">
                    <%= if author_name do %>
                      by {author_name}
                    <% end %>
                  </p>
                </div>
                <button
                  type="button"
                  phx-click="restore_graph"
                  phx-value-title={graph.title}
                  class="inline-flex items-center gap-1 rounded-lg bg-green-50 px-3 py-1.5 text-xs font-semibold text-green-700 hover:bg-green-100 transition"
                >
                  <.icon name="hero-eye" class="w-3.5 h-3.5" /> Restore
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
