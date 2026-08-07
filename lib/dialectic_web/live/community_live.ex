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
       page_description:
         "Explore community-built RationalGrids, curated questions, and partner collections.",
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
    <div class="min-h-screen bg-slate-100 text-slate-900">
      <div class="mx-auto w-full max-w-7xl px-4 py-6 sm:px-6 sm:py-8 lg:px-8">
        <header
          id="community-page-header"
          class="mb-5 flex flex-col gap-4 rounded-3xl bg-slate-950 px-5 py-4 text-white shadow-lg sm:px-6 sm:py-5 lg:flex-row lg:items-center lg:justify-between"
        >
          <div class="max-w-3xl">
            <p class="text-xs font-semibold uppercase tracking-[0.18em] text-teal-300">
              Community
            </p>
            <h1 class="mt-1 text-2xl font-semibold tracking-tight sm:text-3xl">
              Explore, expand, and challenge ideas together.
            </h1>
            <p class="mt-2 max-w-2xl text-sm leading-5 text-slate-300">
              Browse living questions from the community, test the reasoning, and add your own branches to help each idea grow.
            </p>
          </div>
          <div class="flex flex-wrap gap-2">
            <.link
              navigate={~p"/?focus=grid#start-here"}
              class="inline-flex items-center gap-2 rounded-full bg-teal-300 px-3.5 py-2 text-sm font-semibold text-slate-950 transition hover:bg-teal-200"
            >
              <.icon name="hero-plus" class="h-4 w-4" /> Create a grid
            </.link>
            <.link
              navigate={~p"/intro/how"}
              class="inline-flex items-center gap-2 rounded-full border border-white/20 bg-white/10 px-3.5 py-2 text-sm font-semibold text-white transition hover:bg-white/15"
            >
              <.icon name="hero-book-open" class="h-4 w-4" /> Read the guide
            </.link>
          </div>
        </header>

        <div class="space-y-5">
          <%= if @featured_grids != [] do %>
            <.curated_grid_section
              items={@featured_grids}
              icon="hero-users"
              icon_class="text-indigo-500"
              title="Partner grids"
              pills={partner_pills(@featured_grids)}
              id_prefix="community-featured"
              section_class="from-indigo-50 via-white to-teal-50"
              icon_wrap_class="bg-indigo-100 text-indigo-700 ring-indigo-200"
            />
          <% end %>

          <section
            id="community-search"
            class="overflow-hidden rounded-[1.75rem] border border-slate-200/80 bg-white shadow-sm"
          >
            <div class="h-1 bg-[linear-gradient(90deg,#0f766e_0%,#f59e0b_48%,#4f46e5_100%)]"></div>
            <div class="bg-[linear-gradient(135deg,#0f172a_0%,#134e4a_54%,#7c2d12_100%)] p-5 text-white sm:p-7">
              <div class="flex flex-col gap-4 lg:flex-row lg:items-end lg:justify-between">
                <div>
                  <p class="text-xs font-semibold uppercase tracking-[0.18em] text-amber-200">
                    Discover community grids
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
                        Find an idea to explore and extend
                    <% end %>
                  </h2>
                  <p class="mt-2 max-w-2xl text-sm leading-6 text-slate-300">
                    Search by question, browse by topic, and find a living thread of ideas to test, challenge, and build on.
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
                    class="h-11 w-full rounded-full border border-white/60 bg-white px-10 pr-4 text-sm text-slate-900 placeholder:text-slate-500 shadow-sm focus:border-amber-300 focus:outline-none focus:ring-2 focus:ring-amber-200"
                    autocomplete="off"
                  />
                </form>
              </div>

              <div class="mt-5">
                <p class="mb-2 text-[11px] font-semibold uppercase tracking-[0.16em] text-white/60">
                  Browse by format or topic
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
                <div class="mt-3 max-h-36 overflow-y-auto rounded-2xl border border-white/10 bg-black/10 p-2">
                  <p class="px-2 pb-1 text-[10px] font-semibold uppercase tracking-[0.16em] text-white/50">
                    Topics from public grids
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
                  No grids match that search yet. Try a broader question or browse by topic above.
                </div>
              <% else %>
                <div
                  id="community-grid-list"
                  class="divide-y divide-slate-200 overflow-hidden rounded-2xl border border-slate-200 bg-white"
                >
                  <%= for {{graph, _count, author_username}, index} <- Enum.with_index(@graphs, 1) do %>
                    <.community_grid_row
                      graph={graph}
                      author_name={author_username}
                      author_marker="@"
                      number={index}
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
    assigns =
      assigns
      |> assign_new(:pills, fn -> [] end)
      |> assign(
        :card_label,
        if(assigns.title == "Partner grids", do: "Partner grid", else: "Curated grid")
      )

    ~H"""
    <section
      id={"#{@id_prefix}-section"}
      class="overflow-hidden rounded-3xl border border-slate-200/80 bg-white shadow-sm"
    >
      <div class="h-1 bg-[linear-gradient(90deg,#0f766e_0%,#f59e0b_48%,#4f46e5_100%)]"></div>
      <div class="border-b border-slate-200/80 bg-slate-50/80 px-4 py-3 sm:px-5">
        <div class="flex flex-wrap items-center justify-between gap-3">
          <div class="flex items-center gap-2.5">
            <span class={[
              "inline-flex h-8 w-8 items-center justify-center rounded-xl ring-1",
              @icon_wrap_class
            ]}>
              <.icon name={@icon} class={"h-4 w-4 " <> @icon_class} />
            </span>
            <div>
              <p class="text-[11px] font-semibold uppercase tracking-[0.18em] text-slate-500">
                Curated
              </p>
              <h2 class="text-lg font-semibold tracking-tight text-slate-950">{@title}</h2>
            </div>
          </div>
          <div :if={@pills != []} class="flex flex-wrap gap-1.5">
            <span
              :for={pill <- @pills}
              class="rounded-full border border-indigo-200 bg-white px-2.5 py-1 text-[11px] font-medium text-slate-700"
            >
              {pill}
            </span>
          </div>
        </div>
      </div>
      <div class="bg-slate-50/40 p-3 sm:p-4">
        <div id={"#{@id_prefix}-grids-list"} class="grid gap-3 md:grid-cols-2 xl:grid-cols-3">
          <%= for item <- @items do %>
            <.grid_card
              graph={item.graph}
              author_name={item.author_name}
              author_marker="@"
              id={@id_prefix <> "-" <> (item.graph.slug || "t-" <> Integer.to_string(:erlang.phash2(item.graph.title || "")))}
              variant={:community_compact}
              label={@card_label}
              tag_limit={3}
            />
          <% end %>
        </div>
      </div>
    </section>
    """
  end

  attr :id, :string, required: true
  attr :graph, :map, required: true
  attr :author_name, :string, default: nil
  attr :author_marker, :string, default: ""
  attr :number, :integer, required: true
  attr :selected_tag, :string, default: nil
  attr :can_generate_tags, :boolean, default: false
  attr :generating_tags, :any, required: true

  defp community_grid_row(assigns) do
    assigns =
      assigns
      |> assign(:title, Map.get(assigns.graph, :title) || "Untitled grid")
      |> assign(:tags, visible_tags(assigns.graph, assigns.selected_tag))
      |> assign(:node_count, graph_node_count(assigns.graph))
      |> assign(:icon_theme, icon_theme(assigns.graph))
      |> assign(:generating_tags?, MapSet.member?(assigns.generating_tags, assigns.graph.title))

    ~H"""
    <article
      id={@id}
      class="group grid gap-4 px-4 py-4 transition hover:bg-slate-50 sm:grid-cols-[minmax(0,1fr)_auto] sm:items-center sm:px-5"
    >
      <div class="flex min-w-0 items-start gap-3 sm:gap-4">
        <div class={[
          "relative flex h-12 w-12 shrink-0 items-center justify-center rounded-xl bg-gradient-to-br shadow-sm ring-1 sm:h-14 sm:w-20",
          @icon_theme
        ]}>
          <span
            aria-label={"Result #{@number}"}
            class="absolute left-1.5 top-1 inline-flex h-5 min-w-5 items-center justify-center rounded-full bg-white/90 px-1 text-[11px] font-bold tabular-nums text-slate-700 shadow-sm ring-1 ring-slate-900/10"
          >
            {@number}
          </span>
          <.icon name="hero-squares-2x2" class="h-6 w-6 sm:h-7 sm:w-7" />
        </div>
        <div class="min-w-0">
          <div class="flex flex-wrap items-center gap-x-3 gap-y-1">
            <.link
              navigate={graph_path(@graph)}
              class="text-base font-semibold leading-6 text-slate-950 transition group-hover:text-teal-700"
            >
              {@title}
            </.link>
            <span class="rounded-full bg-slate-100 px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wide text-slate-500">
              Community grid
            </span>
          </div>
          <%= if is_binary(@author_name) and String.trim(@author_name) != "" do %>
            <.link
              navigate={~p"/u/#{@author_name}"}
              class="mt-1 inline-flex text-xs font-medium text-teal-700 hover:text-teal-900"
            >
              by {@author_marker}{@author_name}
            </.link>
          <% end %>
          <p class="mt-1 line-clamp-2 text-sm leading-5 text-slate-600">
            {preview_sentence(@graph)}
          </p>
          <div class="mt-2 flex flex-wrap items-center gap-1.5">
            <%= if @tags == [] do %>
              <span class="rounded-md bg-slate-100 px-2 py-0.5 text-[11px] font-medium text-slate-500">
                Untagged
              </span>
              <button
                :if={@can_generate_tags}
                id={@id <> "-generate-tags"}
                type="button"
                phx-click="generate_tags"
                phx-value-identifier={@graph.slug || @graph.title}
                disabled={@generating_tags?}
                class="inline-flex items-center gap-1 rounded-md bg-teal-50 px-2 py-0.5 text-[11px] font-semibold text-teal-700 ring-1 ring-inset ring-teal-200 transition hover:bg-teal-100 disabled:cursor-wait disabled:opacity-60"
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
                class={[
                  "rounded-md px-2 py-0.5 text-[11px] font-semibold ring-1 ring-inset",
                  tag_pill_classes(tag)
                ]}
              >
                #{tag}
              </span>
            <% end %>
          </div>
        </div>
      </div>
      <div class="flex items-center justify-between gap-4 border-t border-slate-100 pt-3 sm:flex-col sm:items-end sm:border-t-0 sm:pt-0">
        <span class="inline-flex items-center gap-1.5 text-xs font-medium text-slate-500">
          <.icon name="hero-squares-2x2" class="h-3.5 w-3.5 text-slate-400" />
          {@node_count} ideas
        </span>
        <.link
          navigate={graph_path(@graph)}
          class="inline-flex items-center gap-1.5 rounded-full bg-slate-950 px-3 py-1.5 text-xs font-semibold text-white transition hover:bg-teal-700"
        >
          View grid <.icon name="hero-arrow-up-right" class="h-3.5 w-3.5" />
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

  defp icon_theme(graph) do
    tags = Map.get(graph, :tags, []) || []

    tags
    |> List.first()
    |> to_string()
    |> String.downcase()
    |> then(fn tag ->
      cond do
        String.contains?(tag, ["science", "technology", "physics"]) ->
          "from-sky-50 via-cyan-50 to-teal-100 text-sky-700 ring-sky-200/80"

        String.contains?(tag, ["history", "politics", "society"]) ->
          "from-amber-50 via-orange-50 to-rose-100 text-amber-700 ring-amber-200/80"

        String.contains?(tag, ["mind", "psychology", "philosophy"]) ->
          "from-indigo-50 via-violet-50 to-fuchsia-100 text-indigo-700 ring-indigo-200/80"

        true ->
          "from-teal-50 via-cyan-50 to-indigo-100 text-teal-700 ring-teal-200/80"
      end
    end)
  end

  defp partner_pills(items) do
    items
    |> Enum.map(&Map.get(&1, :author_name))
    |> Enum.filter(fn name -> is_binary(name) and String.trim(name) != "" end)
    |> Enum.uniq()
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
