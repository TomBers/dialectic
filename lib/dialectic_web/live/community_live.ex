defmodule DialecticWeb.CommunityLive do
  use DialecticWeb, :live_view

  alias Dialectic.DbActions.Graphs
  import DialecticWeb.GridCardComp

  on_mount {DialecticWeb.UserAuth, :mount_current_user}

  @limit 12
  @topic_limit 50
  @tag_generation_timeout_ms :timer.minutes(6)

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Phoenix.PubSub.subscribe(Dialectic.PubSub, "graphs")

    socket =
      socket
      |> assign(
        page_title: "Community Grids",
        page_description: "Browse public and partner grids built with RationalGrid.",
        search_term: "",
        active_tag: nil,
        active_category: nil,
        active_size: "all",
        total_count: 0,
        page: 1,
        page_count: 1,
        sort: "newest",
        browse_params: %{},
        topic_filter: "",
        topic_form: to_form(%{"topic_filter" => ""}),
        sort_form: to_form(%{"sort" => "newest"}),
        size_form: to_form(%{"size" => "all"}),
        generating_tags: MapSet.new(),
        tag_generation_jobs: %{},
        search_form: to_form(%{"search" => ""})
      )
      |> stream_configure(:topics,
        dom_id: fn topic -> "community-topic-" <> Base.url_encode64(topic.id, padding: false) end
      )
      |> stream(:topics, [])
      |> stream_configure(:graphs,
        dom_id: fn item -> graph_dom_id(item.graph, "community-grid") end
      )
      |> stream(:graphs, [])

    {:ok, socket, layout: false}
  end

  @impl true
  def handle_params(params, _url, socket) do
    search = trimmed_string(params["search"])
    tag = resolve_tag(params["tag"])

    category_param =
      if params["category"] in ["curated", "partners", "all"],
        do: params["category"]

    category = category_param || "all"
    legacy_size = %{"seedlings" => "small", "deep_dives" => "large"}[params["category"]]
    size = normalize_size(params["size"] || legacy_size)

    sort = if params["sort"] in ["updated", "largest"], do: params["sort"], else: "newest"

    browse_params =
      clean_params(%{
        "search" => search,
        "tag" => if(tag, do: Graphs.normalize_tag(tag)),
        "category" => category_param,
        "size" => size,
        "sort" => if(sort != "newest", do: sort)
      })

    {:noreply,
     socket
     |> assign_new(:topic_count, &Graphs.count_public_tags/0)
     |> assign(
       search_term: search,
       active_tag: tag,
       active_category: category,
       active_size: size,
       sort: sort,
       page: parse_page(params["page"]),
       browse_params: browse_params,
       search_form: to_form(%{"search" => search}),
       sort_form: to_form(%{"sort" => sort}),
       size_form: to_form(%{"size" => size})
     )
     |> load_results()
     |> stream_topics()}
  end

  @impl true
  def handle_event("search", %{"search" => term}, socket) do
    {:noreply,
     push_patch(socket,
       to: browse_path(socket.assigns.browse_params, %{"search" => trimmed_string(term)})
     )}
  end

  def handle_event("sort", %{"sort" => sort}, socket) do
    sort = if sort in ["updated", "largest"], do: sort

    {:noreply,
     push_patch(socket, to: browse_path(socket.assigns.browse_params, %{"sort" => sort}))}
  end

  def handle_event("filter_topics", %{"topic_filter" => term}, socket) do
    term = trimmed_string(term)

    {:noreply,
     socket
     |> assign(topic_filter: term, topic_form: to_form(%{"topic_filter" => term}))
     |> stream_topics()}
  end

  def handle_event("load_more_topics", _params, socket) do
    if socket.assigns.more_topics? do
      {:noreply, stream_topics(socket, reset: false)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("filter_size", %{"size" => size}, socket) do
    {:noreply,
     push_patch(socket,
       to: browse_path(socket.assigns.browse_params, %{"size" => normalize_size(size)})
     )}
  end

  def handle_event("generate_tags", %{"identifier" => identifier}, socket) do
    if admin?(socket.assigns.current_user) do
      graph = Graphs.get_graph_by_slug_or_title(identifier)

      cond do
        is_nil(graph) ->
          {:noreply, put_flash(socket, :error, "Grid not found")}

        tagged?(graph) ->
          {:noreply, socket}

        true ->
          auto_tagger =
            Application.get_env(
              :dialectic,
              :auto_tagger_module,
              Dialectic.Categorisation.AutoTagger
            )

          case auto_tagger.tag_graph(graph) do
            :ok ->
              {:noreply, mark_tags_generating(socket, graph.title, nil)}

            {:ok, pid} ->
              {:noreply, mark_tags_generating(socket, graph.title, pid)}

            _error ->
              {:noreply, put_flash(socket, :error, "Could not start tag generation")}
          end
      end
    else
      {:noreply, put_flash(socket, :error, "Only admins can generate tags")}
    end
  end

  @impl true
  def handle_info({:tags_updated, title, tags}, socket) do
    {:noreply,
     socket
     |> clear_tag_generation(title)
     |> assign(:topic_count, Graphs.count_public_tags())
     |> load_results(%{title => tags})
     |> stream_topics()}
  end

  def handle_info({:DOWN, monitor_ref, :process, _pid, reason}, socket) do
    case job_for_monitor(socket.assigns.tag_generation_jobs, monitor_ref) do
      nil ->
        {:noreply, socket}

      {title, _job} when reason == :normal ->
        jobs = put_in(socket.assigns.tag_generation_jobs[title].monitor_ref, nil)
        {:noreply, assign(socket, :tag_generation_jobs, jobs)}

      {title, _job} ->
        {:noreply,
         socket
         |> clear_tag_generation(title)
         |> load_results()
         |> put_flash(:error, "Tag generation stopped unexpectedly")}
    end
  end

  def handle_info({:tag_generation_timeout, title}, socket) do
    if MapSet.member?(socket.assigns.generating_tags, title) do
      {:noreply,
       socket
       |> clear_tag_generation(title)
       |> load_results()
       |> put_flash(:error, "Tag generation timed out. Please try again.")}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="min-h-screen bg-[#f4f1e9] text-slate-950">
        <div class="mx-auto w-full max-w-7xl px-4 py-7 sm:px-6 lg:px-8">
          <header id="community-page-header" class="border-b border-stone-300 pb-6">
            <div class="flex items-start justify-between gap-5">
              <div>
                <p class="text-xs font-semibold uppercase tracking-[0.18em] text-teal-800">
                  Explore together
                </p>
                <h1
                  id="community-page-title"
                  class="mt-2 font-serif text-3xl font-semibold tracking-tight sm:text-4xl"
                >
                  {if @active_tag, do: "#{@active_tag} grids", else: "Community grids"}
                </h1>
                <p
                  :if={@active_tag}
                  id="community-topic-description"
                  class="mt-2 max-w-2xl text-sm leading-6 text-slate-600"
                >
                  {@page_description}
                </p>
                <p
                  :if={!@active_tag}
                  id="community-introduction"
                  class="mt-2 max-w-2xl text-sm leading-6 text-slate-600"
                >
                  Challenge ideas, add your own thoughts and questions, and build on what others have
                  started. Explore topics together through community grids.
                </p>
              </div>
              <.link
                id="community-create-grid"
                navigate={~p"/?focus=grid#start-here"}
                class="inline-flex shrink-0 items-center gap-1.5 rounded-md bg-slate-950 px-3 py-2.5 text-sm font-semibold text-white hover:bg-teal-900"
              >
                <.icon name="hero-plus" class="h-4 w-4" /><span class="hidden sm:inline">Create a grid</span><span class="sm:hidden">Create</span>
              </.link>
            </div>
            <.form
              for={@search_form}
              id="community-search-form"
              phx-change="search"
              phx-submit="search"
              class="relative mt-5 max-w-3xl"
            >
              <.input
                id="community-search-input"
                field={@search_form[:search]}
                type="search"
                aria-label="Search community grids"
                phx-debounce="300"
                placeholder={
                  if @active_tag,
                    do: "Search within #{@active_tag}…",
                    else: "Search questions or topics…"
                }
                class="h-12 w-full rounded-md border border-stone-300 bg-white px-4 pr-11 text-base text-slate-950 shadow-sm placeholder:text-slate-400 focus:border-teal-600 focus:outline-none focus:ring-2 focus:ring-teal-100"
                autocomplete="off"
              />
              <.icon
                name="hero-magnifying-glass"
                class="pointer-events-none absolute right-4 top-3.5 h-5 w-5 text-teal-800"
              />
            </.form>
          </header>

          <div
            id="community-browser"
            class="mt-6 grid items-start gap-6 lg:grid-cols-[15rem_minmax(0,1fr)] lg:gap-8"
          >
            <aside aria-label="Browse topics" class="min-w-0 lg:sticky lg:top-14">
              <details
                id="community-topic-panel"
                open
                class="group rounded-lg border border-stone-300 bg-white"
              >
                <summary class="flex cursor-pointer list-none items-center justify-between gap-2 px-4 py-3 text-sm font-semibold">
                  <span>Browse topics
                  <span class="ml-1 text-xs font-normal text-slate-500">{@topic_count}</span></span>
                  <.icon
                    name="hero-chevron-down"
                    class="h-4 w-4 text-slate-500 transition group-open:rotate-180"
                  />
                </summary>
                <div class="border-t border-stone-200 px-3 pb-3 pt-2">
                  <.form
                    for={@topic_form}
                    id="community-topic-search-form"
                    phx-change="filter_topics"
                    phx-submit="filter_topics"
                  >
                    <.input
                      id="community-topic-search-input"
                      field={@topic_form[:topic_filter]}
                      type="search"
                      aria-label="Find a topic"
                      placeholder="Find a topic…"
                      phx-debounce="150"
                      autocomplete="off"
                      class="h-10 w-full rounded-md border border-stone-200 bg-stone-50 px-3 text-sm text-slate-900 placeholder:text-slate-400 focus:border-teal-600 focus:outline-none focus:ring-2 focus:ring-teal-100"
                    />
                  </.form>
                  <.link
                    id="community-all-topics"
                    href={browse_path(@browse_params, %{"tag" => nil})}
                    aria-current={if is_nil(@active_tag), do: "page"}
                    class={[
                      "mt-2 flex items-center justify-between rounded-md px-3 py-2 text-sm font-semibold",
                      if(is_nil(@active_tag),
                        do: "bg-teal-50 text-teal-900",
                        else: "text-slate-600 hover:bg-stone-50"
                      )
                    ]}
                  >All topics <.icon name="hero-squares-2x2" class="h-4 w-4" /></.link>
                  <div
                    id="community-topics"
                    phx-update="stream"
                    class="mt-1 grid max-h-40 grid-cols-2 gap-0.5 overflow-y-auto lg:max-h-[calc(100vh-20rem)] lg:grid-cols-1"
                  >
                    <%= for {id, topic} <- @streams.topics do %>
                      <.link
                        id={id}
                        href={browse_path(@browse_params, %{"tag" => topic.id})}
                        aria-current={if @active_tag == topic.tag, do: "page"}
                        class={[
                          "flex min-w-0 items-center justify-between gap-2 rounded-md px-3 py-2 text-sm",
                          if(@active_tag == topic.tag,
                            do: "bg-teal-50 font-semibold text-teal-900",
                            else: "text-slate-600 hover:bg-stone-50 hover:text-teal-900"
                          )
                        ]}
                      ><span class="truncate">{topic.tag}</span><span class="text-xs tabular-nums text-slate-400">{topic.count}</span></.link>
                    <% end %>
                  </div>
                  <button
                    :if={@more_topics?}
                    id="community-more-topics"
                    type="button"
                    phx-click="load_more_topics"
                    phx-disable-with="Loading…"
                    aria-controls="community-topics"
                    class="mt-2 w-full rounded-md px-3 py-2 text-sm font-semibold text-teal-800 hover:bg-teal-50"
                  >
                    Show more topics
                  </button>
                  <p
                    :if={@visible_topic_count == 0}
                    id="community-no-topics"
                    class="px-3 py-4 text-sm text-slate-500"
                  >
                    No matching topics. Try a broader term.
                  </p>
                </div>
              </details>
            </aside>

            <section id="community-search" aria-label="Community grid results" class="min-w-0">
              <nav
                id="community-format-filters"
                aria-label="Browse grid collections"
                class="flex gap-1 overflow-x-auto border-b border-stone-300 pb-3"
              >
                <%= for {category, label} <- [{"all", "All grids"}, {"curated", "Curated grids"}, {"partners", "Partner grids"}] do %>
                  <.link
                    id={"community-format-#{category}"}
                    href={browse_path(@browse_params, %{"category" => category})}
                    aria-current={if @active_category == category, do: "page"}
                    class={category_class(@active_category == category)}
                  >{label}</.link>
                <% end %>
              </nav>
              <div class="flex flex-wrap items-end justify-between gap-3 py-4">
                <div aria-live="polite">
                  <h2 id="community-results-heading" class="text-lg font-semibold">
                    {results_heading(@search_term, @active_tag, @active_category, @active_size)}
                  </h2>
                  <p id="community-result-count" class="mt-1 text-xs text-slate-500">
                    {result_count_label(@total_count, @page, @page_size)}
                  </p>
                </div>
                <div class="flex flex-wrap items-end gap-3">
                  <.form
                    for={@size_form}
                    id="community-size-form"
                    phx-change="filter_size"
                    class="w-56"
                  >
                    <.input
                      id="community-size-input"
                      field={@size_form[:size]}
                      type="select"
                      label="Grid size"
                      options={[
                        {"All sizes", "all"},
                        {"Large grids · 21+ ideas", "large"},
                        {"Medium grids · 5–20 ideas", "medium"},
                        {"Small grids · 0–4 ideas", "small"}
                      ]}
                      class="h-10 w-full rounded-md border border-stone-300 bg-white px-3 text-sm text-slate-700 focus:border-teal-600 focus:outline-none focus:ring-2 focus:ring-teal-100"
                    />
                  </.form>
                  <.form for={@sort_form} id="community-sort-form" phx-change="sort" class="w-44">
                    <.input
                      id="community-sort-input"
                      field={@sort_form[:sort]}
                      type="select"
                      label="Sort grids"
                      options={[
                        {"Newest first", "newest"},
                        {"Recently updated", "updated"},
                        {"Most ideas", "largest"}
                      ]}
                      class="h-10 w-full rounded-md border border-stone-300 bg-white px-3 text-sm text-slate-700 focus:border-teal-600 focus:outline-none focus:ring-2 focus:ring-teal-100"
                    />
                  </.form>
                </div>
              </div>
              <div
                :if={
                  @active_tag || @search_term != "" || @active_category not in ["curated", "all"] ||
                    @active_size != "all"
                }
                id="community-active-filters"
                class="mb-4 flex flex-wrap items-center gap-2 text-xs"
              >
                <.link
                  :if={@active_tag}
                  id="community-clear-topic"
                  href={browse_path(@browse_params, %{"tag" => nil})}
                  class="inline-flex items-center gap-1 rounded-full bg-teal-100 px-3 py-1.5 font-medium text-teal-900"
                >{@active_tag}<.icon name="hero-x-mark" class="h-3.5 w-3.5" /><span class="sr-only">Remove topic filter</span></.link>
                <.link
                  id="community-clear-filters"
                  href={~p"/community"}
                  class="px-1 py-1.5 font-medium text-slate-600 underline underline-offset-2 hover:text-teal-800"
                >Clear filters</.link>
              </div>
              <div
                id="community-grid-list"
                phx-update="stream"
                class="divide-y divide-stone-200 overflow-hidden rounded-lg border border-stone-300 bg-white"
              >
                <div
                  :if={@total_count == 0}
                  id="community-empty-results"
                  class="px-6 py-12 text-center"
                >
                  <.icon name="hero-magnifying-glass" class="mx-auto h-7 w-7 text-stone-400" />
                  <p class="mt-3 font-semibold text-slate-800">No grids match these filters.</p>
                  <p class="mt-1 text-sm text-slate-500">
                    Try another question or browse all community grids.
                  </p>
                  <.link
                    id="community-empty-reset"
                    href={~p"/community"}
                    class="mt-4 inline-flex text-sm font-semibold text-teal-800 underline underline-offset-4"
                  >Browse all grids</.link>
                </div>
                <%= for {id, item} <- @streams.graphs do %>
                  <.community_grid_row
                    id={id}
                    graph={item.graph}
                    author_name={item.author_name}
                    selected_tag={@active_tag}
                    can_generate_tags={admin?(@current_user)}
                    generating_tags={@generating_tags}
                  />
                <% end %>
              </div>
              <nav
                :if={@page_count > 1}
                id="community-pagination"
                aria-label="Grid result pages"
                class="mt-5 flex items-center justify-between gap-3"
              >
                <.link
                  :if={@page > 1}
                  id="community-previous-page"
                  href={browse_path(@browse_params, %{"page" => @page - 1})}
                  rel="prev"
                  class="inline-flex items-center gap-1.5 rounded-md border border-stone-300 bg-white px-4 py-2 text-sm font-medium text-slate-700 hover:border-teal-600"
                ><.icon name="hero-arrow-left" class="h-4 w-4" />Previous</.link>
                <span :if={@page == 1}></span>
                <span id="community-page-number" class="text-sm tabular-nums text-slate-500">Page {@page} of {@page_count}</span>
                <.link
                  :if={@page < @page_count}
                  id="community-next-page"
                  href={browse_path(@browse_params, %{"page" => @page + 1})}
                  rel="next"
                  class="inline-flex items-center gap-1.5 rounded-md border border-stone-300 bg-white px-4 py-2 text-sm font-medium text-slate-700 hover:border-teal-600"
                >Next<.icon name="hero-arrow-right" class="h-4 w-4" /></.link>
                <span :if={@page == @page_count}></span>
              </nav>
            </section>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  attr :id, :string, required: true
  attr :graph, :map, required: true
  attr :author_name, :string, default: nil
  attr :selected_tag, :string, default: nil
  attr :can_generate_tags, :boolean, default: false
  attr :generating_tags, :any, required: true

  defp community_grid_row(assigns) do
    tags = visible_tags(assigns.graph, assigns.selected_tag)

    assigns =
      assigns
      |> assign(:title, display_title(assigns.graph))
      |> assign(:tags, tags)
      |> assign(:node_count, graph_node_count(assigns.graph))
      |> assign(:created_label, created_label(assigns.graph))
      |> assign(:accent_style, row_accent_style(tags))
      |> assign(:generating_tags?, MapSet.member?(assigns.generating_tags, assigns.graph.title))

    ~H"""
    <article
      id={@id}
      data-role="community-grid-row"
      class="group relative grid gap-5 px-5 py-4 pl-6 transition hover:bg-[#fbfaf6] sm:grid-cols-[minmax(0,1fr)_auto] sm:items-center sm:px-6 sm:pl-7"
    >
      <div aria-hidden="true" class="absolute inset-y-0 left-0 w-1" style={@accent_style}></div>
      <div class="min-w-0">
        <.link
          navigate={graph_path(@graph)}
          class="text-balance font-serif text-xl font-semibold leading-7 tracking-tight text-slate-950 transition group-hover:text-teal-800 hover:text-teal-900 sm:text-2xl"
        >
          {@title}
        </.link>

        <div
          data-role="community-grid-meta"
          class="mt-2 flex flex-wrap items-center gap-x-2 gap-y-1 text-xs text-slate-500"
        >
          <%= if is_binary(@author_name) and String.trim(@author_name) != "" do %>
            <.link
              navigate={~p"/u/#{@author_name}"}
              class="font-medium text-slate-600 transition hover:text-teal-800"
            >
              by @{@author_name}
            </.link>
            <span aria-hidden="true">·</span>
          <% end %>
          <span aria-label={"Created " <> @created_label}>{@created_label}</span>
          <span aria-hidden="true">·</span>
          <span>{idea_count_label(@node_count)}</span>
        </div>

        <div class="mt-4 flex flex-wrap items-center gap-x-4 gap-y-2">
          <%= if @tags == [] do %>
            <span class="text-xs font-medium text-slate-500">Untagged</span>
            <button
              :if={@can_generate_tags}
              id={@id <> "-generate-tags"}
              type="button"
              phx-click="generate_tags"
              phx-value-identifier={@graph.slug || @graph.title}
              disabled={@generating_tags?}
              class="inline-flex items-center gap-1 text-xs font-semibold text-teal-700 transition hover:text-teal-900 disabled:cursor-wait disabled:opacity-60"
            >
              <.icon
                name={if(@generating_tags?, do: "hero-arrow-path", else: "hero-sparkles")}
                class={tag_generation_icon_class(@generating_tags?)}
              />
              {if(@generating_tags?, do: "Generating...", else: "Generate tags")}
            </button>
          <% else %>
            <.link
              :for={tag <- @tags}
              href={~p"/community?tag=#{Graphs.normalize_tag(tag)}"}
              class="inline-flex items-center gap-1.5 text-xs font-medium text-slate-600"
            >
              <span
                aria-hidden="true"
                class="h-1.5 w-1.5 shrink-0 rounded-full"
                style={"background-color: " <> tag_color_hex(tag)}
              ></span>
              {tag}
            </.link>
          <% end %>
        </div>
      </div>

      <div class="flex items-center border-t border-stone-200 pt-4 sm:border-t-0 sm:pt-0">
        <.link
          navigate={graph_path(@graph)}
          class="inline-flex items-center gap-1.5 text-xs font-semibold text-teal-800 transition hover:text-teal-950"
          aria-label={"Read grid: " <> @title}
        >
          Read grid
          <.icon
            name="hero-arrow-right"
            class="h-3.5 w-3.5 transition-transform group-hover:translate-x-0.5"
          />
        </.link>
      </div>
    </article>
    """
  end

  defp mark_tags_generating(socket, title, pid) do
    monitor_ref = if is_pid(pid), do: Process.monitor(pid)

    timer_ref =
      Process.send_after(self(), {:tag_generation_timeout, title}, @tag_generation_timeout_ms)

    assign(socket,
      generating_tags: MapSet.put(socket.assigns.generating_tags, title),
      tag_generation_jobs:
        Map.put(socket.assigns.tag_generation_jobs, title, %{
          monitor_ref: monitor_ref,
          timer_ref: timer_ref
        })
    )
    |> load_results()
  end

  defp clear_tag_generation(socket, title) do
    {job, jobs} = Map.pop(socket.assigns.tag_generation_jobs, title)

    if job do
      if job.monitor_ref, do: Process.demonitor(job.monitor_ref, [:flush])
      Process.cancel_timer(job.timer_ref)
    end

    assign(socket,
      generating_tags: MapSet.delete(socket.assigns.generating_tags, title),
      tag_generation_jobs: jobs
    )
  end

  defp job_for_monitor(jobs, monitor_ref) do
    Enum.find(jobs, fn {_title, job} -> job.monitor_ref == monitor_ref end)
  end

  defp tag_generation_icon_class(true), do: "h-3 w-3 animate-spin"
  defp tag_generation_icon_class(false), do: "h-3 w-3"

  defp admin?(%{is_admin: true}), do: true
  defp admin?(_user), do: false

  defp tagged?(%{tags: tags}) when is_list(tags), do: tags != []
  defp tagged?(_graph), do: false

  defp visible_tags(graph, selected_tag) do
    tags =
      (Map.get(graph, :tags, []) || [])
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.uniq_by(&Graphs.normalize_tag/1)

    case Enum.find(tags, fn tag ->
           selected_tag && Graphs.normalize_tag(tag) == Graphs.normalize_tag(selected_tag)
         end) do
      nil -> Enum.take(tags, 3)
      matching_tag -> [matching_tag | Enum.reject(tags, &(&1 == matching_tag))] |> Enum.take(3)
    end
  end

  defp load_results(socket, updated_tags \\ %{}) do
    result =
      Graphs.browse_public_graphs(
        search: socket.assigns.search_term,
        tag: socket.assigns.active_tag,
        category: socket.assigns.active_category,
        size: socket.assigns.active_size,
        sort: socket.assigns.sort,
        page: socket.assigns.page,
        page_size: @limit
      )

    entries =
      Enum.map(result.entries, fn item ->
        case Map.fetch(updated_tags, item.id) do
          {:ok, tags} -> put_in(item.graph.tags, tags)
          :error -> item
        end
      end)

    canonical_params =
      socket.assigns.browse_params
      |> Map.take(["tag"])
      |> Map.put(
        "category",
        if(socket.assigns.active_category == "curated" and is_nil(socket.assigns.active_tag),
          do: "curated"
        )
      )
      |> Map.put("page", if(result.page > 1, do: result.page))

    noindex =
      socket.assigns.search_term != "" or
        socket.assigns.active_category not in ["curated", "all"] or
        socket.assigns.active_size != "all" or
        (socket.assigns.active_category == "curated" and not is_nil(socket.assigns.active_tag)) or
        socket.assigns.sort != "newest" or
        (not is_nil(socket.assigns.active_tag) and result.total_count == 0) or
        socket.assigns.page != result.page

    title =
      page_title(
        socket.assigns.search_term,
        socket.assigns.active_tag,
        socket.assigns.active_category,
        socket.assigns.active_size
      )

    socket
    |> assign(
      total_count: result.total_count,
      page: result.page,
      page_count: result.page_count,
      page_size: result.page_size,
      page_title: if(result.page > 1, do: title <> " · Page #{result.page}", else: title),
      page_description: page_description(socket.assigns.active_tag),
      canonical_url: DialecticWeb.Endpoint.url() <> browse_path(canonical_params),
      noindex: noindex
    )
    |> stream(:graphs, entries, reset: true)
  end

  defp stream_topics(socket, opts \\ []) do
    reset? = Keyword.get(opts, :reset, true)
    offset = if reset?, do: 0, else: socket.assigns.visible_topic_count

    result =
      Graphs.search_public_tags(socket.assigns.topic_filter, limit: @topic_limit, offset: offset)

    socket
    |> assign(
      visible_topic_count: offset + length(result.topics),
      more_topics?: result.has_more?
    )
    |> stream(
      :topics,
      Enum.map(result.topics, fn {tag, count} ->
        %{id: Graphs.normalize_tag(tag), tag: tag, count: count}
      end),
      reset: reset?
    )
  end

  defp browse_path(params, overrides \\ %{}) do
    params = params |> Map.merge(overrides) |> clean_params()
    if params == %{}, do: ~p"/community", else: ~p"/community?#{params}"
  end

  defp clean_params(params) do
    params
    |> Map.reject(fn {key, value} ->
      value in [nil, ""] or (key == "page" and value in [1, "1"]) or
        (key in ["category", "size"] and value == "all")
    end)
  end

  defp parse_page(value) when is_binary(value) do
    case Integer.parse(value) do
      {page, ""} when page > 0 -> min(page, 1_000_000)
      _ -> 1
    end
  end

  defp parse_page(_), do: 1

  defp normalize_size(size) when size in ["small", "medium", "large"], do: size
  defp normalize_size(_size), do: "all"

  defp results_heading(search, tag, category, size) do
    cond do
      search != "" -> "Search results for \"#{search}\""
      tag -> "Ideas tagged with \"#{tag}\""
      category == "curated" -> "Curated grids"
      category == "partners" -> "Partner grids"
      size == "large" -> "Large grids"
      size == "medium" -> "Medium grids"
      size == "small" -> "Small grids"
      true -> "All community grids"
    end
  end

  defp result_count_label(0, _page, _size), do: "0 grids"
  defp result_count_label(1, _page, _size), do: "1 grid"

  defp result_count_label(count, page, size),
    do: "#{(page - 1) * size + 1}–#{min(page * size, count)} of #{count} grids"

  defp trimmed_string(value) when is_binary(value), do: String.trim(value)
  defp trimmed_string(_value), do: ""

  defp resolve_tag(value) do
    case trimmed_string(value) do
      "" -> nil
      tag -> Graphs.public_tag_label(tag) || tag
    end
  end

  defp page_description(nil), do: "Browse public and partner grids built with RationalGrid."

  defp page_description(tag) do
    "Explore public grids about #{tag}. Follow questions, compare perspectives, and examine sources shared by the RationalGrid community."
  end

  defp category_class(true),
    do: "shrink-0 rounded-md bg-slate-950 px-3.5 py-2 text-sm font-semibold text-white"

  defp category_class(false),
    do:
      "shrink-0 rounded-md px-3.5 py-2 text-sm font-medium text-slate-600 transition hover:bg-white hover:text-slate-950"

  defp graph_dom_id(graph, prefix) do
    suffix = graph.slug || Integer.to_string(:erlang.phash2(graph.title || "graph"))
    prefix <> "-" <> suffix
  end

  defp graph_node_count(%{node_count: count}) when is_integer(count), do: count

  defp graph_node_count(graph) do
    nodes =
      (Map.get(graph, :data) || %{})
      |> then(fn data -> Map.get(data, "nodes") || Map.get(data, :nodes) || [] end)

    if is_list(nodes) do
      Enum.count(nodes, fn node ->
        Map.get(node, "compound", Map.get(node, :compound, false)) != true
      end)
    else
      0
    end
  end

  defp idea_count_label(1), do: "1 idea"
  defp idea_count_label(count), do: "#{count} ideas"

  defp display_title(graph) do
    title = Map.get(graph, :title) || "Untitled grid"

    case String.next_grapheme(title) do
      {first, rest} -> String.upcase(first) <> rest
      nil -> "Untitled grid"
    end
  end

  defp row_accent_style(tags) do
    colors = tags |> Enum.map(&tag_color_hex/1) |> Enum.uniq()

    gradient_colors =
      case colors do
        [] -> [tag_color_hex(""), "#cbd5e1"]
        [color] -> [color, "#cbd5e1"]
        colors -> colors
      end

    "background-image: linear-gradient(180deg, #{Enum.join(gradient_colors, ", ")});"
  end

  defp page_title(search, tag, category, size) do
    cond do
      is_binary(tag) and tag != "" -> "Tagged: #{tag} · Community"
      category == "curated" -> "Curated Grids · Community"
      category == "partners" -> "Partner Grids · Community"
      is_binary(search) and search != "" -> "Search · Community"
      size == "large" -> "Large Grids · Community"
      size == "medium" -> "Medium Grids · Community"
      size == "small" -> "Small Grids · Community"
      true -> "Community Grids"
    end
  end
end
