defmodule DialecticWeb.CommunityLive do
  use DialecticWeb, :live_view

  alias Dialectic.DbActions.Graphs
  import DialecticWeb.GridCardComp

  on_mount {DialecticWeb.UserAuth, :mount_current_user}

  @limit 12
  @tag_limit 30
  @tag_generation_timeout_ms :timer.minutes(6)

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Phoenix.PubSub.subscribe(Dialectic.PubSub, "graphs")

    {:ok,
     assign(socket,
       page_title: "Community Grids",
       page_description: "Browse public and partner grids built with RationalGrid.",
       search_term: "",
       active_tag: nil,
       active_category: nil,
       graphs: [],
       popular_tags: [],
       featured_grids: [],
       generating_tags: MapSet.new(),
       tag_generation_jobs: %{}
     )}
  end

  @impl true
  def handle_params(params, _url, socket) do
    search_term = Map.get(params, "search", "")
    tag = Map.get(params, "tag")
    category = Map.get(params, "category")

    {:noreply,
     assign(socket,
       search_term: search_term,
       active_tag: tag,
       active_category: category,
       graphs: fetch_graphs(search_term, tag, category),
       popular_tags: Graphs.list_popular_tags(@tag_limit),
       featured_grids: Graphs.list_curated_grids("featured", 20),
       page_title: page_title(search_term, tag, category)
     )}
  end

  @impl true
  def handle_event("search", %{"search" => term}, socket) do
    params = if term == "", do: %{}, else: %{"search" => term}
    {:noreply, push_patch(socket, to: ~p"/community?#{params}")}
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
    graphs =
      Enum.map(socket.assigns.graphs, fn {graph, count, username} ->
        if graph.title == title do
          {Map.put(graph, :tags, tags), count, username}
        else
          {graph, count, username}
        end
      end)

    socket = clear_tag_generation(socket, title)

    {:noreply,
     assign(socket,
       graphs: graphs,
       popular_tags: Graphs.list_popular_tags(@tag_limit)
     )}
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
         |> put_flash(:error, "Tag generation stopped unexpectedly")}
    end
  end

  def handle_info({:tag_generation_timeout, title}, socket) do
    if MapSet.member?(socket.assigns.generating_tags, title) do
      {:noreply,
       socket
       |> clear_tag_generation(title)
       |> put_flash(:error, "Tag generation timed out. Please try again.")}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-[#f4f1e9] text-slate-950">
      <div class="mx-auto w-full max-w-7xl px-4 py-6 sm:px-6 sm:py-8 lg:px-8">
        <header
          id="community-page-header"
          class="mb-6 flex flex-col gap-5 border border-stone-300 border-l-4 border-l-teal-700 bg-white px-5 py-5 shadow-sm sm:px-7 sm:py-6 lg:flex-row lg:items-end lg:justify-between"
        >
          <div class="max-w-3xl">
            <p class="text-xs font-semibold uppercase tracking-[0.2em] text-teal-800">
              Community
            </p>
            <h1 class="mt-2 font-serif text-4xl font-semibold tracking-tight text-slate-950 sm:text-5xl">
              Explore public grids.
            </h1>
            <p class="mt-3 max-w-2xl text-sm leading-6 text-slate-600">
              Read the branches, test the reasoning, or continue from any idea.
            </p>
          </div>
          <div class="flex flex-wrap gap-2">
            <.link
              navigate={~p"/?focus=grid#start-here"}
              class="inline-flex items-center gap-2 rounded-md bg-slate-950 px-3.5 py-2 text-sm font-semibold text-white transition hover:bg-slate-800"
            >
              <.icon name="hero-plus" class="h-4 w-4" /> Create a grid
            </.link>
            <.link
              navigate={~p"/intro/how"}
              class="inline-flex items-center gap-2 border-b border-slate-500 px-1 py-2 text-sm font-semibold text-slate-800 transition hover:border-teal-700 hover:text-teal-800"
            >
              <.icon name="hero-book-open" class="h-4 w-4" /> How it works
            </.link>
          </div>
        </header>

        <div class="space-y-5">
          <%= if @featured_grids != [] do %>
            <.curated_grid_section
              items={@featured_grids}
              title="Partner grids"
              id_prefix="community-featured"
            />
          <% end %>

          <section
            id="community-search"
            class="overflow-hidden border border-stone-300 bg-white shadow-sm"
          >
            <div class="h-1 bg-teal-700"></div>
            <div class="bg-slate-950 p-5 text-white sm:p-7">
              <div class="flex flex-col gap-4 lg:flex-row lg:items-end lg:justify-between">
                <div>
                  <p class="text-xs font-semibold uppercase tracking-[0.18em] text-amber-200">
                    Community library
                  </p>
                  <h2 id="community-results-heading" class="mt-2 text-2xl font-semibold sm:text-3xl">
                    <%= cond do %>
                      <% @active_tag -> %>
                        Ideas tagged with "{@active_tag}"
                      <% @active_category == "deep_dives" -> %>
                        Deep dives
                      <% @active_category == "seedlings" -> %>
                        Seedlings
                      <% @search_term != "" -> %>
                        Search results for "{@search_term}"
                      <% true -> %>
                        Find a question to explore
                    <% end %>
                  </h2>
                  <p class="mt-2 max-w-2xl text-sm leading-6 text-slate-300">
                    Search by question or topic.
                  </p>
                </div>
                <form
                  phx-change="search"
                  phx-submit="search"
                  class="relative w-full lg:w-80"
                  onsubmit="return false;"
                >
                  <span class="pointer-events-none absolute inset-y-0 left-0 flex items-center pl-3 text-slate-400">
                    <.icon name="hero-magnifying-glass" class="h-4 w-4" />
                  </span>
                  <input
                    type="text"
                    name="search"
                    value={@search_term}
                    phx-debounce="300"
                    placeholder="Search by question or topic..."
                    class="h-11 w-full rounded-md border border-white/60 bg-white px-10 pr-4 text-sm text-slate-900 placeholder:text-slate-500 shadow-sm focus:border-teal-300 focus:outline-none focus:ring-2 focus:ring-teal-200"
                    autocomplete="off"
                  />
                </form>
              </div>

              <div class="mt-5">
                <p class="mb-2 text-[11px] font-semibold uppercase tracking-[0.16em] text-white/60">
                  Filter by format or topic
                </p>
                <div class="flex flex-wrap gap-2">
                  <.link
                    patch={~p"/community"}
                    class={category_class(!@active_category && !@active_tag && @search_term == "")}
                  >
                    Most recent
                  </.link>
                  <.link
                    patch={~p"/community?category=deep_dives"}
                    class={category_class(@active_category == "deep_dives")}
                  >
                    Deep dives
                  </.link>
                  <.link
                    patch={~p"/community?category=seedlings"}
                    class={category_class(@active_category == "seedlings")}
                  >
                    Seedlings
                  </.link>
                </div>
                <div class="mt-3 max-h-36 overflow-y-auto border border-white/15 bg-black/10 p-2">
                  <p class="px-2 pb-1 text-[10px] font-semibold uppercase tracking-[0.16em] text-white/50">
                    Topics
                  </p>
                  <div class="flex flex-wrap gap-2">
                    <%= for %{tag: tag, count: count} <- display_popular_tags(@popular_tags, :all) do %>
                      <.link
                        patch={~p"/community?tag=#{tag}"}
                        class={category_class(@active_tag == tag)}
                      >
                        #{tag} <span class="text-[10px] opacity-70">{count}</span>
                      </.link>
                    <% end %>
                  </div>
                </div>
              </div>
            </div>

            <div class="bg-slate-50/70 p-4 sm:p-5">
              <%= if @graphs == [] do %>
                <div class="border border-dashed border-slate-300 bg-white p-8 text-center text-sm text-slate-600">
                  No grids found. Try a broader search or another topic.
                </div>
              <% else %>
                <div
                  id="community-grid-list"
                  class="divide-y divide-slate-200 overflow-hidden border border-slate-200 bg-white"
                >
                  <%= for {graph, _count, author_username} <- @graphs do %>
                    <.community_grid_row
                      graph={graph}
                      author_name={author_username}
                      selected_tag={@active_tag}
                      can_generate_tags={admin?(@current_user)}
                      generating_tags={@generating_tags}
                      id={graph_dom_id(graph, "community-grid")}
                    />
                  <% end %>
                </div>
              <% end %>
            </div>
          </section>
        </div>
      </div>
    </div>
    """
  end

  defp curated_grid_section(assigns) do
    assigns = assign_new(assigns, :pills, fn -> [] end)

    ~H"""
    <section id={"#{@id_prefix}-section"} class="w-full min-w-0 py-2">
      <div class="mb-5 flex items-center gap-4">
        <h2 class="shrink-0 text-sm font-semibold uppercase tracking-[0.16em] text-slate-700">
          {@title}
        </h2>
        <div
          aria-hidden="true"
          class="h-px flex-1 bg-[linear-gradient(90deg,#2dd4bf_0%,#818cf8_52%,#fbbf24_100%)]"
        >
        </div>
        <div :if={@pills != []} class="flex flex-wrap gap-1.5">
          <span
            :for={pill <- @pills}
            class="border-l border-slate-400 pl-2 text-[11px] font-medium text-slate-700"
          >
            {pill}
          </span>
        </div>
      </div>
      <div id={"#{@id_prefix}-grids-list"} class="grid gap-5 md:grid-cols-2 xl:grid-cols-3">
        <%= for item <- @items do %>
          <.grid_card
            graph={item.graph}
            author_name={item.author_name}
            author_marker="@"
            id={@id_prefix <> "-" <> (item.graph.slug || "t-" <> Integer.to_string(:erlang.phash2(item.graph.title || "")))}
            variant={:partner}
            show_badge={false}
            tag_limit={3}
          />
        <% end %>
      </div>
    </section>
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
      |> assign(:accent_style, row_accent_style(tags))
      |> assign(:generating_tags?, MapSet.member?(assigns.generating_tags, assigns.graph.title))

    ~H"""
    <article
      id={@id}
      data-role="community-grid-row"
      class="group relative grid gap-5 px-5 py-5 pl-6 transition hover:bg-[#fbfaf6] sm:grid-cols-[minmax(0,1fr)_auto] sm:items-center sm:px-6 sm:pl-7"
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
          <span>{updated_label(@graph)}</span>
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
            <span
              :for={tag <- @tags}
              class="inline-flex items-center gap-1.5 text-xs font-medium text-slate-600"
            >
              <span
                aria-hidden="true"
                class="h-1.5 w-1.5 shrink-0 rounded-full"
                style={"background-color: " <> tag_color_hex(tag)}
              >
              </span>
              {tag}
            </span>
          <% end %>
        </div>
      </div>

      <div class="flex items-center border-t border-stone-200 pt-4 sm:border-t-0 sm:pt-0">
        <.link
          navigate={graph_path(@graph)}
          class="inline-flex items-center gap-1.5 text-xs font-semibold text-teal-800 transition hover:text-teal-950"
          aria-label={"Read " <> @title}
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
    tags = Map.get(graph, :tags, []) || []

    case Enum.find(tags, fn tag ->
           selected_tag && String.downcase(tag) == String.downcase(selected_tag)
         end) do
      nil -> Enum.take(tags, 3)
      matching_tag -> [matching_tag | Enum.reject(tags, &(&1 == matching_tag))] |> Enum.take(3)
    end
  end

  defp fetch_graphs(search_term, tag, category) do
    cond do
      is_binary(tag) and tag != "" ->
        Graphs.list_graphs_by_tag(tag, nil)
        |> Enum.map(fn {g, username} -> {g, 0, username} end)

      category == "deep_dives" ->
        Graphs.list_deep_dives(@limit) |> Enum.map(fn {g, username} -> {g, 0, username} end)

      category == "seedlings" ->
        Graphs.list_seedlings(@limit) |> Enum.map(fn {g, username} -> {g, 0, username} end)

      true ->
        Graphs.all_graphs_with_notes(search_term, limit: @limit)
    end
  end

  defp display_popular_tags(tags, limit) do
    tags
    |> Enum.reduce(%{}, fn {tag, count}, acc ->
      key = tag |> to_string() |> String.downcase()

      Map.update(acc, key, %{tag: to_string(tag), count: count}, fn existing ->
        %{existing | count: existing.count + count}
      end)
    end)
    |> Map.values()
    |> Enum.sort_by(fn item -> {-item.count, String.downcase(item.tag)} end)
    |> then(fn topics -> if limit == :all, do: topics, else: Enum.take(topics, limit) end)
  end

  defp category_class(true),
    do:
      "rounded-full border border-white bg-white px-3 py-1.5 text-xs font-semibold text-slate-950"

  defp category_class(false),
    do:
      "rounded-full border border-white/15 bg-white/10 px-3 py-1.5 text-xs font-medium text-white/85 transition hover:border-white/30 hover:bg-white/15"

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

  defp page_title(search, tag, category) do
    cond do
      is_binary(tag) and tag != "" -> "Tagged: #{tag} · Community"
      category == "deep_dives" -> "Deep Dives · Community"
      category == "seedlings" -> "Seedlings · Community"
      is_binary(search) and search != "" -> "Search · Community"
      true -> "Community Grids"
    end
  end
end
