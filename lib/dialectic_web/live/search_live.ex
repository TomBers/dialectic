defmodule DialecticWeb.SearchLive do
  use DialecticWeb, :live_view

  alias Dialectic.Search
  @page_size 12

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(
       page_title: "Search RationalGrid",
       page_description:
         "Search ideas, explanations, and sources across public RationalGrid grids.",
       noindex: true,
       query: "",
       result_count: 0,
       page: 1,
       more_results?: false,
       form: to_form(%{"q" => ""})
     )
     |> stream_configure(:results, dom_id: &result_id/1)
     |> stream(:results, []), layout: false}
  end

  @impl true
  def handle_params(params, _url, socket) do
    query = Search.normalize_query(Map.get(params, "q", ""))
    page = page_number(params["page"])
    results = Search.search_public(query, limit: @page_size + 1, offset: (page - 1) * @page_size)
    page_results = Enum.take(results, @page_size)

    {:noreply,
     socket
     |> assign(
       query: query,
       page: page,
       more_results?: length(results) > @page_size,
       result_count: length(page_results),
       form: to_form(%{"q" => query}),
       page_title: page_title(query)
     )
     |> stream(:results, page_results, reset: true)}
  end

  @impl true
  def handle_event("search", %{"q" => query}, socket) do
    query = Search.normalize_query(query)
    params = if query == "", do: %{}, else: %{"q" => query}

    {:noreply, push_patch(socket, to: ~p"/search?#{params}")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.search_content {assigns} />
    </Layouts.app>
    """
  end

  defp search_content(assigns) do
    ~H"""
    <div class="min-h-screen bg-[#f4f1e9] text-slate-950">
      <div class="mx-auto w-full max-w-5xl px-4 py-8 sm:px-6 sm:py-12 lg:px-8">
        <header class="border border-stone-300 border-l-4 border-l-teal-700 bg-white px-5 py-6 shadow-sm sm:px-8 sm:py-8">
          <p class="text-xs font-semibold uppercase tracking-[0.2em] text-teal-800">
            Across RationalGrid
          </p>
          <h1 class="mt-2 font-serif text-4xl font-semibold tracking-tight sm:text-5xl">
            Find an idea, not just a grid.
          </h1>
          <p class="mt-3 max-w-2xl text-sm leading-6 text-slate-600 sm:text-base">
            Search public questions, explanations, and source passages. Open any result in its original context.
          </p>

          <.form
            id="global-search-form"
            for={@form}
            phx-change="search"
            phx-submit="search"
            class="relative mt-6 max-w-3xl"
          >
            <label for="global-search-input" class="sr-only">
              Search public ideas, explanations, and sources
            </label>
            <span class="pointer-events-none absolute inset-y-0 left-0 flex items-center pl-4 text-slate-500">
              <.icon name="hero-magnifying-glass" class="h-5 w-5" />
            </span>
            <.input
              id="global-search-input"
              field={@form[:q]}
              type="search"
              phx-debounce="300"
              placeholder="Search ideas, explanations, or sources..."
              autocomplete="off"
              autofocus
              class="h-[3.25rem] w-full rounded-md border border-slate-400 bg-white py-3 pl-12 pr-4 text-base text-slate-950 shadow-sm placeholder:text-slate-500 focus:border-teal-700 focus:outline-none focus:ring-2 focus:ring-teal-200"
            />
          </.form>
          <p class="mt-2 text-xs text-slate-500">Enter at least two characters.</p>
        </header>

        <section id="global-search-results" aria-live="polite" class="mt-6">
          <%= cond do %>
            <% @query == "" -> %>
              <div
                id="global-search-prompt"
                class="border border-stone-300 bg-white px-5 py-8 text-center shadow-sm"
              >
                <.icon name="hero-document-magnifying-glass" class="mx-auto h-7 w-7 text-teal-700" />
                <p class="mt-3 font-serif text-xl font-semibold">Search the public library</p>
                <p class="mt-1 text-sm text-slate-600">
                  Try a person, concept, argument, book, or phrase.
                </p>
              </div>
            <% String.length(@query) < 2 -> %>
              <div
                id="global-search-too-short"
                class="border border-stone-300 bg-white px-5 py-6 text-sm text-slate-600 shadow-sm"
              >
                Keep typing to search across public grids.
              </div>
            <% @result_count == 0 -> %>
              <div
                id="global-search-empty"
                class="border border-stone-300 bg-white px-5 py-8 text-center shadow-sm"
              >
                <p class="font-serif text-xl font-semibold">No public ideas found</p>
                <p class="mt-1 text-sm text-slate-600">Try a shorter term or a different phrase.</p>
              </div>
            <% true -> %>
              <div class="mb-3 flex items-baseline justify-between gap-4 px-1">
                <h2 class="font-serif text-2xl font-semibold">Results for “{@query}”</h2>
                <p class="shrink-0 text-xs font-medium text-slate-500">
                  {result_count_label(@result_count)}{if(@more_results?, do: " on this page")}
                </p>
              </div>

              <div
                id="global-search-items"
                phx-update="stream"
                class="divide-y divide-stone-200 border border-stone-300 bg-white shadow-sm"
              >
                <article
                  :for={{dom_id, result} <- @streams.results}
                  id={dom_id}
                  class="px-5 py-6 sm:px-7"
                >
                  <div class="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
                    <div class="min-w-0">
                      <.link
                        navigate={graph_path(result.graph)}
                        class="font-serif text-2xl font-semibold leading-tight text-slate-950 transition hover:text-teal-800"
                      >
                        {result.graph.title}
                      </.link>
                      <div class="mt-2 flex flex-wrap items-center gap-x-2 gap-y-1 text-xs text-slate-500">
                        <%= if present?(result.author_name) do %>
                          <span>{"by @" <> result.author_name}</span>
                          <span aria-hidden="true">·</span>
                        <% end %>
                        <span :for={tag <- Enum.take(result.graph.tags, 3)}>{tag}</span>
                      </div>
                    </div>
                    <span
                      :if={result.match_reason}
                      class="shrink-0 rounded-full border border-teal-200 bg-teal-50 px-2.5 py-1 text-[11px] font-semibold text-teal-900"
                    >
                      {match_reason_label(result.match_reason)}
                    </span>
                  </div>

                  <div :if={result.matches != []} class="mt-5 space-y-2">
                    <p class="text-[11px] font-semibold uppercase tracking-[0.16em] text-slate-500">
                      Matching ideas
                    </p>
                    <.link
                      :for={match <- result.matches}
                      id={match_id(result, match)}
                      navigate={graph_path(result.graph, node_id(match))}
                      class="group block border-l-2 border-stone-300 bg-[#faf9f5] px-4 py-3 transition hover:border-teal-700 hover:bg-teal-50/50"
                    >
                      <div class="flex items-start justify-between gap-3">
                        <h3 class="font-semibold leading-5 text-slate-900 group-hover:text-teal-900">
                          {Map.get(match, :title)}
                        </h3>
                        <span class="shrink-0 text-[10px] font-semibold uppercase tracking-wide text-slate-500">
                          {Map.get(match, :search_preview_label)}
                        </span>
                      </div>
                      <p
                        :if={Map.get(match, :search_preview)}
                        class="mt-1.5 line-clamp-2 text-sm leading-5 text-slate-600"
                      >
                        {Map.get(match, :search_preview)}
                      </p>
                    </.link>
                  </div>
                </article>
              </div>
          <% end %>
          <nav
            :if={@page > 1 || @more_results?}
            id="global-search-pagination"
            aria-label="Search result pages"
            class="mt-5 flex items-center justify-between gap-4"
          >
            <.link
              :if={@page > 1}
              id="global-search-previous"
              patch={~p"/search?q=#{@query}&page=#{@page - 1}"}
              class="font-semibold text-teal-800 underline underline-offset-4"
            >
              Previous
            </.link>
            <span class="text-sm text-slate-600">Page {@page}</span>
            <.link
              :if={@more_results?}
              id="global-search-next"
              patch={~p"/search?q=#{@query}&page=#{@page + 1}"}
              class="font-semibold text-teal-800 underline underline-offset-4"
            >
              Next
            </.link>
          </nav>
        </section>
      </div>
    </div>
    """
  end

  defp page_title(""), do: "Search RationalGrid"
  defp page_title(query), do: "Search: #{query}"

  defp page_number(value) when is_binary(value) do
    case Integer.parse(value) do
      {page, ""} when page > 0 -> min(page, 1_000)
      _ -> 1
    end
  end

  defp page_number(_value), do: 1

  defp result_count_label(1), do: "1 grid"
  defp result_count_label(count), do: "#{count} grids"

  defp result_id(result), do: "global-search-result-#{result.graph.slug}"

  defp match_id(result, match),
    do: "global-search-result-#{result.graph.slug}-node-#{node_id(match)}"

  defp node_id(node), do: Map.get(node, :id) || Map.get(node, "id")

  defp match_reason_label(:title), do: "Grid title"
  defp match_reason_label(:topic), do: "Topic"
  defp match_reason_label(_reason), do: "Match"

  defp present?(value), do: is_binary(value) and String.trim(value) != ""
end
