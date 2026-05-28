defmodule DialecticWeb.HomeLive do
  use DialecticWeb, :live_view
  alias Dialectic.DbActions.Graphs
  alias Dialectic.Graph.GraphActions
  alias Dialectic.Graph.Vertex
  alias Dialectic.Highlights
  alias DialecticWeb.Utils.UserUtils
  require Logger

  on_mount {DialecticWeb.UserAuth, :mount_current_user}

  @impl true
  def mount(params, _session, socket) do
    socket = assign(socket, :loading_graph, nil)
    if connected?(socket), do: Phoenix.PubSub.subscribe(Dialectic.PubSub, "graphs")

    user = UserUtils.current_identity(socket.assigns)
    initial_content = params["initial_prompt"]

    changeset =
      GraphActions.create_new_node(user)
      |> Vertex.changeset(if initial_content, do: %{content: initial_content}, else: %{})

    prompt_mode = "university"

    {:ok,
     assign(socket,
       og_image: DialecticWeb.Endpoint.url() <> ~p"/images/graph_live.webp",
       search_term: "",
       active_tag: nil,
       active_category: nil,
       graphs: [],
       popular_tags: [],
       limit: 20,
       generating: MapSet.new(),
       user: user,
       form: to_form(changeset),
       prompt_mode: prompt_mode,
       ask_question: true,
       graph_id: nil,
       preview_seed: home_preview_seed(),
       curated_grids: [],
       all_curated_grids: [],
       featured_grids: [],
       all_featured_grids: [],
       quote_of_day: nil,
       quick_tags: [],
       featured_grids_expanded: false
     )}
  end

  @impl true
  def handle_params(params, _url, socket) do
    search_term = Map.get(params, "search", "")
    tag = Map.get(params, "tag")
    category = Map.get(params, "category")
    limit = 20

    graphs = fetch_graphs(search_term, tag, category, limit)
    popular_tags = Graphs.list_popular_tags()
    # Fetch more items than needed to have a pool for randomization
    all_curated_grids = Graphs.list_curated_grids("curated", 20)
    all_featured_grids = Graphs.list_curated_grids("featured", 20)
    quote_of_day = Highlights.quote_of_the_day()

    curated_grids = preview_curated_grids(all_curated_grids, 3, socket.assigns.preview_seed)

    featured_grids =
      preview_curated_grids(all_featured_grids, 3, socket.assigns.preview_seed)

    {:noreply,
     assign(socket,
       search_term: search_term,
       active_tag: tag,
       active_category: category,
       graphs: graphs,
       popular_tags: popular_tags,
       curated_grids: curated_grids,
       all_curated_grids: all_curated_grids,
       featured_grids: featured_grids,
       all_featured_grids: all_featured_grids,
       quote_of_day: quote_of_day,
       page_title: page_title(search_term, tag, category)
     )}
  end

  @impl true
  def handle_event("search", %{"search" => term}, socket) do
    # For live search, we update the URL params which triggers handle_params
    # We maintain existing category filters if present? Usually search clears category filters
    # or works within them. Let's make search global for now (clears other filters).
    params =
      if term == "" do
        %{}
      else
        %{"search" => term}
      end

    {:noreply, push_patch(socket, to: ~p"/?#{params}")}
  end

  @impl true
  def handle_event("reply-and-answer", %{"vertex" => %{"content" => answer}} = params, socket) do
    mode_param = Map.get(params, "mode")
    {:noreply, submit_new_grid(socket, answer, mode_param)}
  end

  @impl true
  def handle_event("generate_tags", %{"title" => title}, socket) do
    case Graphs.get_graph_by_title(title) do
      nil ->
        {:noreply, put_flash(socket, :error, "Grid not found")}

      graph ->
        Dialectic.Categorisation.AutoTagger.tag_graph(graph)
        {:noreply, assign(socket, generating: MapSet.put(socket.assigns.generating, title))}
    end
  end

  @impl true
  def handle_event("toggle_featured_grids", _params, socket) do
    {:noreply, assign(socket, :featured_grids_expanded, !socket.assigns.featured_grids_expanded)}
  end

  @impl true
  def handle_async(:create_graph_flow, {:ok, {:ok, title}}, socket) do
    # Fetch the newly created graph to get its slug
    case Graphs.get_graph_by_title(title) do
      nil ->
        # This shouldn't happen since we just created the graph
        {:noreply, put_flash(socket, :error, "Grid not found after creation")}

      graph ->
        {:noreply, redirect(socket, to: graph_editor_path(graph))}
    end
  end

  def handle_async(:create_graph_flow, {:ok, {:error, reason}}, socket) do
    Logger.error("Grid creation failed: #{inspect(reason)}")

    error_message =
      case reason do
        :save_failed -> "Failed to save grid. Please try again."
        _ -> "Failed to create grid. Please try again."
      end

    {:noreply,
     socket
     |> put_flash(:error, error_message)
     |> assign(:loading_graph, nil)}
  end

  def handle_async(:create_graph_flow, {:ok, _}, socket) do
    Logger.warning("Grid creation returned unexpected result")

    {:noreply,
     socket
     |> put_flash(:error, "Failed to create grid")
     |> assign(:loading_graph, nil)}
  end

  def handle_async(:create_graph_flow, {:exit, reason}, socket) do
    Logger.error("Grid creation process crashed: #{inspect(reason)}")

    {:noreply,
     socket
     |> put_flash(:error, "Grid creation failed unexpectedly. Please try again.")
     |> assign(:loading_graph, nil)}
  end

  @impl true
  def handle_info({:submit_new_grid, answer, mode_param}, socket) do
    {:noreply, submit_new_grid(socket, answer, mode_param)}
  end

  @impl true
  def handle_info({:graph_creation_update, status}, socket) do
    loading = socket.assigns.loading_graph

    if loading do
      new_steps = loading.steps ++ [status]
      {:noreply, assign(socket, :loading_graph, %{loading | status: status, steps: new_steps})}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:tags_updated, title, tags}, socket) do
    graphs =
      Enum.map(socket.assigns.graphs, fn {g, c, username} ->
        if g.title == title do
          {Map.put(g, :tags, tags), c, username}
        else
          {g, c, username}
        end
      end)

    popular_tags = Graphs.list_popular_tags()

    {:noreply,
     assign(socket,
       graphs: graphs,
       popular_tags: popular_tags,
       generating: MapSet.delete(socket.assigns.generating, title)
     )}
  end

  defp create_graph_task(title, answer, prompt_mode, current_user, parent_pid) do
    mode_str = prompt_mode || "university"

    mode =
      case mode_str do
        "expert" -> :expert
        "high_school" -> :high_school
        "simple" -> :simple
        _ -> :university
      end

    user_identity =
      case current_user do
        %{email: email} -> email
        _ -> "anonymous"
      end

    Dialectic.Graph.Creator.create(answer, current_user, user_identity,
      mode: mode,
      title: title,
      progress_callback: fn status -> send(parent_pid, {:graph_creation_update, status}) end
    )
  end

  defp submit_new_grid(socket, answer, mode_param) do
    title = Graphs.sanitize_title(answer)
    socket = if mode_param, do: assign(socket, prompt_mode: mode_param), else: socket

    cond do
      socket.assigns.loading_graph != nil ->
        socket

      title == "untitled-idea" ->
        put_flash(socket, :error, "Please enter a question or topic.")

      true ->
        case Graphs.get_graph_by_title(title) do
          nil ->
            parent_pid = self()
            prompt_mode = socket.assigns[:prompt_mode]
            current_user = socket.assigns[:current_user]

            socket
            |> assign(:loading_graph, %{title: title, status: "Initializing...", steps: []})
            |> start_async(:create_graph_flow, fn ->
              create_graph_task(title, answer, prompt_mode, current_user, parent_pid)
            end)

          existing_graph ->
            redirect(socket, to: graph_editor_path(existing_graph))
        end
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="w-screen bg-slate-100 font-sans text-slate-900 antialiased">
      <div class="relative w-screen overflow-hidden bg-gradient-to-b from-slate-100 via-white to-slate-100">
        <%= if @loading_graph do %>
          <div class="fixed inset-0 z-50 flex items-center justify-center bg-slate-950/80 backdrop-blur-sm">
            <div class="max-w-md w-full p-8 bg-white/10 border border-white/20 rounded-2xl shadow-2xl backdrop-blur-md">
              <div class="flex flex-col items-center gap-6">
                <div class="relative w-16 h-16">
                  <div class="absolute inset-0 border-4 border-white/20 rounded-full"></div>
                  <div class="absolute inset-0 border-4 border-t-white rounded-full animate-spin">
                  </div>
                </div>

                <div class="space-y-2 text-center">
                  <h3 class="text-xl font-bold text-white">{@loading_graph.title}</h3>
                  <p class="text-indigo-200">{@loading_graph.status}</p>
                </div>

                <div class="w-full space-y-2">
                  <%= for step <- Enum.reverse(@loading_graph.steps) |> Enum.take(3) do %>
                    <div class="text-sm text-white/60 flex items-center gap-2">
                      <.icon name="hero-check-circle" class="w-4 h-4 text-green-400" />
                      {step}
                    </div>
                  <% end %>
                </div>
              </div>
            </div>
          </div>
        <% end %>
        <div class="relative z-10 pb-4 sm:pb-5">
          <% preview_items =
            editor_pick_preview_items(
              @curated_grids,
              @graphs
            ) %>

          <section
            id="start-here"
            class="w-full bg-gradient-to-br from-[#2b0a78] via-[#3a0ca3] to-[#4361ee] px-4 py-4 text-white shadow-xl sm:px-6 sm:py-5"
          >
            <div class="mx-auto grid w-full max-w-7xl grid-cols-1 gap-3 lg:grid-cols-12">
              <div class="rounded-[1.75rem] border border-white/15 bg-white/10 p-4 shadow-sm ring-1 ring-white/10 sm:p-5 lg:col-span-6">
                <div class="flex flex-wrap items-center justify-between gap-3">
                  <h1 class="flex items-center gap-3 text-3xl font-extrabold tracking-tight text-white sm:text-4xl">
                    <img
                      src={~p"/images/favicon.webp"}
                      alt=""
                      aria-hidden="true"
                      class="h-10 w-10 rounded-xl shadow-lg"
                    />
                    <span>RationalGrid</span>
                  </h1>
                </div>

                <div class="mt-4 space-y-3">
                  <p class="text-xs font-semibold uppercase tracking-[0.22em] text-indigo-100/80">
                    Read ideas as grids, not walls of text
                  </p>
                  <h2 class="text-2xl font-semibold leading-tight tracking-tight text-white sm:text-4xl">
                    Explore big ideas that do not fit in a chat box.
                  </h2>
                  <p class="max-w-2xl text-sm leading-6 text-indigo-50/90 sm:text-base">
                    Grids turn a topic into paths you can follow: claims, counterpoints,
                    sources, and the next question worth asking.
                  </p>
                </div>

                <div class="mt-4 flex flex-wrap gap-2">
                  <.link
                    navigate={~p"/about"}
                    class="inline-flex items-center gap-2 rounded-full border border-white/20 bg-white/10 px-3 py-1.5 text-sm font-semibold text-white/90 transition hover:bg-white/15 hover:text-white"
                  >
                    About <.icon name="hero-arrow-right" class="h-4 w-4" />
                  </.link>
                  <.link
                    href="#explore"
                    class="inline-flex items-center gap-2 rounded-full border border-white/25 bg-white/10 px-3 py-1.5 text-sm font-semibold text-white transition hover:bg-white/15"
                  >
                    <.icon name="hero-magnifying-glass" class="h-4 w-4" /> Browse grids
                  </.link>
                </div>
              </div>

              <div
                id="quote-of-the-day"
                class="rounded-[1.75rem] border border-white/20 bg-white/95 p-4 text-slate-950 shadow-[0_18px_42px_rgba(15,23,42,0.18)] ring-1 ring-white/40 sm:p-5 lg:col-span-6"
              >
                <div class="space-y-3">
                  <div class="inline-flex items-center gap-2 rounded-full bg-indigo-50 px-3 py-1 text-[11px] font-bold uppercase tracking-[0.18em] text-indigo-700 ring-1 ring-indigo-100">
                    <.icon name="hero-sparkles" class="h-3.5 w-3.5" /> Quote of the day
                  </div>

                  <%= if @quote_of_day do %>
                    <blockquote class="text-xl font-semibold italic leading-snug tracking-tight text-slate-950 sm:text-2xl">
                      “{quote_text(@quote_of_day)}”
                    </blockquote>

                    <%= if quote_note(@quote_of_day) != "" do %>
                      <p class="rounded-2xl border border-indigo-100 bg-indigo-50/70 px-3 py-2 text-sm leading-6 text-indigo-950">
                        {quote_note(@quote_of_day)}
                      </p>
                    <% end %>

                    <div class="flex flex-col gap-3 border-t border-slate-200 pt-3 sm:flex-row sm:items-end sm:justify-between">
                      <div class="min-w-0">
                        <p class="text-xs font-semibold uppercase tracking-[0.16em] text-slate-500">
                          Opens a grid on
                        </p>
                        <.link
                          navigate={
                            graph_path(
                              @quote_of_day.graph,
                              @quote_of_day.highlight.node_id,
                              highlight: @quote_of_day.highlight.id
                            )
                          }
                          class="mt-1 block truncate text-base font-semibold text-indigo-800 transition hover:text-indigo-950"
                        >
                          {@quote_of_day.graph.title}
                        </.link>
                        <div class="mt-2 flex flex-wrap items-center gap-2">
                          <%= if author_visible?(@quote_of_day.author_name) do %>
                            <.link
                              navigate={author_profile_path(@quote_of_day.author_name)}
                              class="inline-flex items-center gap-1 text-xs font-medium text-slate-600 transition hover:text-indigo-700"
                            >
                              <.icon name="hero-user-circle" class="h-3.5 w-3.5" />
                              {"@" <> @quote_of_day.author_name}
                            </.link>
                          <% end %>
                          <%= for tag <- Enum.take(@quote_of_day.graph.tags || [], 3) do %>
                            <span class={[
                              "inline-flex items-center rounded-full px-2 py-0.5 text-[11px] font-semibold ring-1 ring-inset",
                              table_tag_color_class(tag)
                            ]}>
                              {tag}
                            </span>
                          <% end %>
                          <span class="inline-flex items-center rounded-full bg-slate-100 px-2 py-0.5 text-[11px] font-semibold text-slate-600 ring-1 ring-slate-200">
                            {graph_node_count(@quote_of_day.graph)} nodes
                          </span>
                        </div>
                      </div>

                      <.link
                        navigate={
                          graph_path(
                            @quote_of_day.graph,
                            @quote_of_day.highlight.node_id,
                            highlight: @quote_of_day.highlight.id
                          )
                        }
                        class="inline-flex shrink-0 items-center gap-2 rounded-full bg-slate-950 px-4 py-2 text-sm font-semibold text-white shadow-sm transition hover:bg-slate-800"
                      >
                        Read grid <.icon name="hero-arrow-right" class="h-4 w-4" />
                      </.link>
                    </div>
                  <% else %>
                    <div class="space-y-3">
                      <blockquote class="text-xl font-semibold italic leading-snug tracking-tight text-slate-950 sm:text-2xl">
                        “Every grid starts with one sharp question.”
                      </blockquote>
                      <p class="text-sm leading-6 text-slate-600">
                        Highlighted quotes from public grids will appear here as the library grows.
                        For now, jump into the popular grids below and find your own thread.
                      </p>
                      <.link
                        href="#explore"
                        class="inline-flex items-center gap-2 rounded-full bg-slate-950 px-4 py-2 text-sm font-semibold text-white shadow-sm transition hover:bg-slate-800"
                      >
                        Browse popular grids <.icon name="hero-arrow-right" class="h-4 w-4" />
                      </.link>
                    </div>
                  <% end %>
                </div>
              </div>
            </div>
          </section>

          <div class="mx-auto max-w-7xl px-4 pt-3 sm:px-6 sm:pt-4">
            <div class="grid grid-cols-1 gap-3 lg:grid-cols-12">
              <section class="relative min-w-0 overflow-hidden rounded-[1.75rem] border border-indigo-200/80 bg-gradient-to-br from-indigo-50 via-white to-sky-50/90 p-4 shadow-sm ring-1 ring-indigo-100 lg:col-span-6">
                <div class="space-y-3">
                  <div>
                    <div class="inline-flex items-center gap-2 rounded-full bg-slate-900 px-3 py-1 text-[11px] font-semibold uppercase tracking-[0.18em] text-indigo-200 shadow-sm">
                      <.icon name="hero-plus" class="h-3.5 w-3.5" /> Create a grid
                    </div>
                    <h2 class="mt-3 text-xl font-semibold tracking-tight text-slate-950">
                      Have a question? Make it explorable.
                    </h2>
                    <p class="mt-2 text-sm leading-6 text-slate-700">
                      Start with a topic, claim, or tension. RationalGrid turns it into a
                      structured opening map.
                    </p>
                  </div>

                  <div class="rounded-[1.4rem] border border-indigo-100/90 bg-white/85 p-2 shadow-[inset_0_1px_0_rgba(255,255,255,0.9),0_10px_26px_rgba(15,23,42,0.08)] ring-1 ring-white/80">
                    <.live_component
                      module={DialecticWeb.NewIdeaFormComp}
                      id="new-idea-form"
                      form={@form}
                    />
                  </div>
                </div>
              </section>

              <section class="min-w-0 overflow-hidden rounded-[1.75rem] border border-slate-900/10 bg-slate-950 p-3 text-white shadow-sm ring-1 ring-slate-900/10 lg:col-span-6">
                <div class="mb-3 flex items-start justify-between gap-3">
                  <div>
                    <p class="text-[11px] font-semibold uppercase tracking-[0.18em] text-sky-200/80">
                      Screenshot
                    </p>
                    <h2 class="mt-1 text-xl font-semibold tracking-tight text-white">
                      What a grid looks like
                    </h2>
                  </div>
                  <.link
                    navigate={~p"/g/happiness-da4f7e"}
                    class="inline-flex shrink-0 items-center gap-1 rounded-full border border-white/15 bg-white/10 px-3 py-1 text-xs font-medium text-white/85 transition hover:border-sky-300/40 hover:bg-white/15 hover:text-white"
                  >
                    Open <.icon name="hero-arrow-top-right-on-square" class="h-3.5 w-3.5" />
                  </.link>
                </div>

                <.link navigate={~p"/g/happiness-da4f7e"} class="group block">
                  <div class="aspect-[16/9] overflow-hidden border border-white/10 bg-slate-900 shadow-[inset_0_1px_0_rgba(255,255,255,0.08)]">
                    <img
                      src={~p"/images/guide/grid-workspace.webp"}
                      alt="Preview of the Happiness grid workspace by TomBers44"
                      class="h-full w-full object-contain object-center transition duration-300 group-hover:scale-[1.015]"
                      loading="lazy"
                    />
                  </div>
                </.link>

                <p class="mt-3 text-sm leading-6 text-slate-300">
                  A finished grid shows branching claims, questions, and context in one workspace.
                </p>
              </section>

              <section class="min-w-0 rounded-[1.75rem] border border-slate-200/90 bg-white/90 p-4 shadow-sm ring-1 ring-slate-200/80 lg:col-span-6">
                <div class="mb-3 flex items-start justify-between gap-3">
                  <div>
                    <div class="inline-flex items-center gap-2 rounded-full bg-slate-100 px-3 py-1 text-[11px] font-semibold uppercase tracking-[0.18em] text-slate-700 ring-1 ring-slate-200">
                      <.icon name="hero-book-open" class="h-3.5 w-3.5" /> Editor picks
                    </div>
                  </div>
                  <.link
                    href="#explore"
                    class="inline-flex items-center justify-center gap-2 rounded-full border border-slate-300 bg-slate-900 px-3 py-1.5 text-sm font-medium text-white shadow-sm transition hover:bg-slate-800"
                  >
                    Browse all
                  </.link>
                </div>

                <div class="space-y-2">
                  <%= if preview_items == [] do %>
                    <div class="rounded-2xl border border-dashed border-slate-300 bg-slate-50 p-4 text-sm leading-6 text-slate-600">
                      Curated grids will appear here. Until then, use Explore below.
                    </div>
                  <% else %>
                    <%= for {item, index} <- Enum.with_index(preview_items) do %>
                      <DialecticWeb.PageHtml.GraphComp.render
                        title={item.graph.title}
                        is_public={item.graph.is_public}
                        link={graph_path(item.graph)}
                        count={0}
                        tags={Enum.take(item.graph.tags || [], 3)}
                        author_name={item.author_name}
                        author_link={author_profile_path(item.author_name)}
                        author_label="by"
                        variant={:light}
                        compact={true}
                        show_exploration_stats={false}
                        node_count={graph_node_count(item.graph)}
                        is_live={false}
                        generating={false}
                        id={"home-pick-#{index}-#{graph_key(item.graph)}"}
                      />
                    <% end %>
                  <% end %>
                </div>
              </section>

              <section
                id="curated"
                class="min-w-0 rounded-[1.75rem] border border-slate-200/80 bg-white/90 p-4 shadow-sm ring-1 ring-slate-200/80 lg:col-span-6"
              >
                <div class="mb-3 flex items-start justify-between gap-3">
                  <div class="min-w-0 space-y-2">
                    <div class="inline-flex items-center gap-2 rounded-full bg-slate-100 px-3 py-1 text-[11px] font-semibold uppercase tracking-[0.18em] text-slate-700 ring-1 ring-slate-200">
                      <.icon name="hero-users" class="h-3.5 w-3.5 text-indigo-500" /> Partner grids
                    </div>

                    <%= if partner_pills(@featured_grids) != [] do %>
                      <div class="flex flex-wrap gap-1.5">
                        <span
                          :for={pill <- partner_pills(@featured_grids)}
                          class="inline-flex items-center rounded-full border border-indigo-200 bg-white/90 px-2.5 py-1 text-[11px] font-medium text-slate-700 shadow-sm"
                        >
                          {pill}
                        </span>
                      </div>
                    <% end %>
                  </div>

                  <.link
                    href="#explore"
                    class="inline-flex items-center justify-center gap-2 rounded-full border border-slate-300 bg-slate-900 px-3 py-1.5 text-sm font-medium text-white shadow-sm transition hover:bg-slate-800"
                  >
                    Browse all
                  </.link>
                </div>

                <div class="space-y-2">
                  <%= if @featured_grids == [] do %>
                    <div class="rounded-2xl border border-dashed border-slate-300 bg-slate-50 p-4 text-sm leading-6 text-slate-600">
                      Partner grids will appear here as more public collections are featured.
                    </div>
                  <% else %>
                    <%= for {item, index} <- Enum.with_index(if(@featured_grids_expanded, do: @all_featured_grids, else: @featured_grids)) do %>
                      <DialecticWeb.PageHtml.GraphComp.render
                        title={item.graph.title}
                        is_public={item.graph.is_public}
                        link={graph_path(item.graph)}
                        count={0}
                        tags={Enum.take(item.graph.tags || [], 3)}
                        author_name={item.author_name}
                        author_link={author_profile_path(item.author_name)}
                        author_label="by"
                        variant={:light}
                        compact={true}
                        show_exploration_stats={false}
                        node_count={graph_node_count(item.graph)}
                        is_live={false}
                        generating={false}
                        id={"featured-#{index}-#{graph_key(item.graph)}"}
                      />
                    <% end %>
                  <% end %>
                </div>

                <%= if length(@all_featured_grids) > 3 do %>
                  <div class="mt-3 flex justify-end">
                    <button
                      type="button"
                      phx-click="toggle_featured_grids"
                      class="inline-flex items-center gap-1 text-sm font-semibold text-indigo-700 transition hover:text-indigo-950"
                    >
                      {if @featured_grids_expanded, do: "Show fewer", else: "See more"}
                      <.icon name="hero-arrow-right" class="h-4 w-4" />
                    </button>
                  </div>
                <% end %>
              </section>

              <div id="explore" class="h-5 lg:col-span-12"></div>
              <!-- Below: All ideas (full-width on desktop, uses available space) -->
              <section class="w-full rounded-3xl bg-white/90 p-2.5 ring-1 ring-slate-200 sm:p-3 lg:col-span-12">
                <div class="rounded-2xl bg-white shadow-sm ring-1 ring-slate-200">
                  <div class="p-2 sm:p-2.5">
                    <div class="rounded-2xl border border-slate-200 bg-gradient-to-r from-slate-50 via-white to-indigo-50/70 p-3 shadow-sm">
                      <div class="flex flex-col gap-3 lg:flex-row lg:items-center lg:justify-between">
                        <div class="min-w-0">
                          <div class="inline-flex items-center gap-1 rounded-full bg-slate-900 px-2.5 py-1 text-[11px] font-semibold uppercase tracking-[0.18em] text-white">
                            <.icon name="hero-sparkles" class="h-3.5 w-3.5" /> Explore
                          </div>
                          <div class="mt-2 flex flex-wrap items-center gap-2">
                            <h2 class="text-lg font-semibold tracking-tight text-slate-900 sm:text-xl">
                              <%= cond do %>
                                <% @active_tag -> %>
                                  Ideas tagged with "{@active_tag}"
                                <% @active_category == "deep_dives" -> %>
                                  Deep Dives
                                <% @active_category == "seedlings" -> %>
                                  Seedlings
                                <% @search_term != "" -> %>
                                  Search results for "{@search_term}"
                                <% true -> %>
                                  Popular Grids
                              <% end %>
                            </h2>
                            <span class="inline-flex items-center rounded-full border border-indigo-200 bg-indigo-50 px-2 py-0.5 text-xs font-medium text-indigo-700">
                              Community-built
                            </span>
                          </div>
                        </div>

                        <div class="w-full lg:w-72">
                          <form
                            phx-change="search"
                            phx-submit="search"
                            class="relative"
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
                              placeholder="Search ideas..."
                              class="h-10 w-full rounded-full border border-slate-300 bg-white px-10 pr-10 text-sm text-slate-900 placeholder:text-slate-500 shadow-sm transition focus:border-indigo-300 focus:outline-none focus:ring-2 focus:ring-indigo-200"
                              autocomplete="off"
                            />
                            <%= if @search_term && @search_term != "" do %>
                              <button
                                type="button"
                                phx-click="search"
                                phx-value-search=""
                                class="absolute inset-y-0 right-0 flex items-center pr-3 text-slate-400 transition-colors hover:text-slate-700"
                              >
                                <.icon name="hero-x-mark" class="h-4 w-4" />
                              </button>
                            <% end %>
                          </form>
                        </div>
                      </div>

                      <div class="mt-3 flex flex-col gap-2 xl:flex-row xl:flex-wrap xl:items-start xl:justify-between">
                        <%= if @popular_tags != [] do %>
                          <div class="flex min-w-0 items-center gap-2">
                            <span class="flex-shrink-0 text-[11px] font-semibold uppercase tracking-[0.18em] text-slate-500">
                              Trending
                            </span>
                            <div class="flex w-full gap-1.5 overflow-x-auto pb-1 -mb-1 xl:w-auto xl:max-w-none xl:flex-wrap xl:overflow-visible">
                              <%= for {tag, count} <- Enum.take(@popular_tags, 6) do %>
                                <.link
                                  patch={~p"/?tag=#{tag}"}
                                  class={[
                                    "inline-flex flex-shrink-0 items-center gap-1 rounded-full border px-2.5 py-1 text-xs font-medium transition-colors whitespace-nowrap",
                                    (@active_tag == tag && "border-slate-900 bg-slate-900 text-white") ||
                                      "border-slate-200 bg-white text-slate-700 hover:border-slate-300 hover:bg-slate-100"
                                  ]}
                                >
                                  <span>#{tag}</span>
                                  <span class={[
                                    "rounded-full px-1.5 py-0.5 text-[10px]",
                                    (@active_tag == tag && "bg-white/15 text-white") ||
                                      "bg-slate-100 text-slate-500"
                                  ]}>
                                    {count}
                                  </span>
                                </.link>
                              <% end %>
                            </div>
                          </div>
                        <% end %>

                        <div class="flex flex-wrap gap-1.5 xl:justify-end">
                          <.link
                            patch={~p"/"}
                            class={[
                              "rounded-full border px-2.5 py-1 text-xs font-medium transition-colors",
                              (!@active_category && !@active_tag && @search_term == "" &&
                                 "border-slate-900 bg-slate-900 text-white") ||
                                "border-slate-200 bg-white text-slate-700 hover:border-slate-300 hover:bg-slate-100"
                            ]}
                          >
                            All
                          </.link>
                          <.link
                            patch={~p"/?category=deep_dives"}
                            class={[
                              "rounded-full border px-2.5 py-1 text-xs font-medium transition-colors",
                              (@active_category == "deep_dives" &&
                                 "border-slate-900 bg-slate-900 text-white") ||
                                "border-slate-200 bg-white text-slate-700 hover:border-slate-300 hover:bg-slate-100"
                            ]}
                          >
                            Deep Dives
                          </.link>
                          <.link
                            patch={~p"/?category=seedlings"}
                            class={[
                              "rounded-full border px-2.5 py-1 text-xs font-medium transition-colors",
                              (@active_category == "seedlings" &&
                                 "border-slate-900 bg-slate-900 text-white") ||
                                "border-slate-200 bg-white text-slate-700 hover:border-slate-300 hover:bg-slate-100"
                            ]}
                          >
                            Seedlings
                          </.link>
                        </div>
                      </div>
                    </div>
                  </div>

                  <div class="border-t border-slate-200">
                    <div id="home-graph-mobile-list" class="space-y-3 p-3 md:hidden">
                      <%= for {g, _count, author_username} <- @graphs do %>
                        <article
                          id={graph_dom_id(g, "home-mobile-graph")}
                          class="rounded-2xl border border-slate-200 bg-gradient-to-br from-white via-slate-50 to-indigo-50/60 p-4 shadow-sm ring-1 ring-slate-200/70"
                        >
                          <div class="flex flex-col gap-3">
                            <div class="min-w-0 space-y-1.5">
                              <.link
                                navigate={graph_path(g)}
                                class="block text-[1.05rem] font-semibold leading-7 tracking-tight text-slate-900 transition hover:text-indigo-700"
                              >
                                {g.title}
                              </.link>

                              <%= if author_visible?(author_username) do %>
                                <.link
                                  navigate={~p"/u/#{author_username}"}
                                  class="inline-flex items-center gap-1 text-xs font-medium text-slate-600 transition hover:text-indigo-700"
                                >
                                  <.icon name="hero-user-circle" class="h-4 w-4" />
                                  by @{author_username}
                                </.link>
                              <% end %>
                            </div>

                            <.link
                              navigate={graph_path(g)}
                              class="inline-flex h-11 w-full items-center justify-center gap-2 rounded-2xl bg-gradient-to-br from-indigo-500 to-sky-500 px-4 text-sm font-semibold text-white shadow-sm ring-1 ring-indigo-500/30 transition-transform hover:scale-[1.01] hover:shadow-md"
                              aria-label={"Open " <> (g.title || "idea")}
                            >
                              <.icon name="hero-magnifying-glass" class="h-4 w-4" />
                              <span>Open</span>
                            </.link>
                          </div>

                          <%= if (g.tags || []) != [] do %>
                            <div class="mt-3 flex flex-wrap gap-1.5">
                              <%= for tag <- Enum.take(g.tags || [], 4) do %>
                                <span class={[
                                  "inline-flex items-center rounded-full px-2.5 py-1 text-[11px] font-semibold ring-1 ring-inset",
                                  table_tag_color_class(tag)
                                ]}>
                                  #{tag}
                                </span>
                              <% end %>
                            </div>
                          <% end %>
                        </article>
                      <% end %>
                    </div>

                    <div class="hidden overflow-x-auto p-3 sm:p-3.5 md:block">
                      <table
                        id="home-graph-desktop-table"
                        class="min-w-full border-separate border-spacing-0 text-left text-sm"
                      >
                        <thead class="bg-slate-50 text-xs uppercase tracking-wide text-slate-600">
                          <tr>
                            <th class="px-4 py-2.5 font-semibold shadow-[inset_0_-1px_0_0_rgb(226_232_240)]">
                              Idea
                            </th>
                            <th class="px-4 py-2.5 font-semibold shadow-[inset_0_-1px_0_0_rgb(226_232_240)]">
                              Tags
                            </th>
                            <th class="px-4 py-2.5 text-right font-semibold shadow-[inset_0_-1px_0_0_rgb(226_232_240)]">
                              Open
                            </th>
                          </tr>
                        </thead>
                        <tbody class="divide-y divide-slate-200">
                          <%= for {g, _count, author_username} <- @graphs do %>
                            <tr class="align-top transition-colors odd:bg-slate-100 even:bg-white hover:bg-indigo-50/80">
                              <td class="px-4 py-3">
                                <%!-- Desktop link (graph view) --%>
                                <.link
                                  navigate={graph_path(g)}
                                  class="line-clamp-2 font-semibold text-slate-900 hover:text-indigo-700"
                                >
                                  {g.title}
                                </.link>
                                <%= if author_visible?(author_username) do %>
                                  <.link
                                    navigate={~p"/u/#{author_username}"}
                                    class="mt-1 inline-flex text-xs text-slate-600 hover:text-indigo-700"
                                  >
                                    by @{author_username}
                                  </.link>
                                <% end %>
                              </td>
                              <td class="px-4 py-3">
                                <div class="flex flex-wrap gap-1">
                                  <%= for tag <- Enum.take(g.tags || [], 4) do %>
                                    <span class={[
                                      "inline-flex items-center rounded-md px-2 py-0.5 text-[11px] font-semibold ring-1 ring-inset",
                                      table_tag_color_class(tag)
                                    ]}>
                                      #{tag}
                                    </span>
                                  <% end %>
                                </div>
                              </td>
                              <td class="px-4 py-3 text-right">
                                <%!-- Desktop link (graph view) --%>
                                <.link
                                  navigate={graph_path(g)}
                                  class="inline-flex h-8 w-8 items-center justify-center rounded-full bg-gradient-to-br from-indigo-500 to-sky-500 text-white shadow-sm ring-1 ring-indigo-500/30 transition-transform hover:scale-105 hover:shadow-md"
                                  aria-label={"Open " <> (g.title || "idea")}
                                >
                                  <.icon name="hero-magnifying-glass" class="h-4 w-4" />
                                  <span class="sr-only">Open</span>
                                </.link>
                              </td>
                            </tr>
                          <% end %>
                        </tbody>
                      </table>
                    </div>
                  </div>
                </div>
              </section>
              <%!-- Social Media Links --%>
              <section class="w-full pb-3 lg:col-span-12">
                <div class="relative overflow-hidden rounded-2xl bg-gradient-to-br from-[#3a0ca3] to-[#4361ee] px-5 py-4 text-white shadow-xl sm:px-6 sm:py-5">
                  <div class="pointer-events-none absolute inset-0">
                    <div class="absolute -top-8 left-10 h-28 w-28 rounded-full bg-white/10 blur-2xl">
                    </div>
                    <div class="absolute -bottom-10 right-8 h-32 w-32 rounded-full bg-indigo-300/25 blur-2xl">
                    </div>
                  </div>
                  <div class="relative flex flex-col items-center gap-2.5">
                    <img
                      src={~p"/images/favicon.webp"}
                      alt="RationalGrid"
                      class="h-10 w-10 rounded-lg shadow-lg"
                    />
                    <p class="text-sm text-white/85">Follow RationalGrid</p>
                    <div class="flex items-center justify-center gap-6">
                      <a
                        href="https://github.com/TomBers/dialectic"
                        target="_blank"
                        rel="noopener noreferrer"
                        class="text-white/70 hover:text-white transition-colors"
                        aria-label="GitHub"
                      >
                        <svg class="h-6 w-6" fill="currentColor" viewBox="0 0 24 24">
                          <path
                            fill-rule="evenodd"
                            d="M12 2C6.477 2 2 6.484 2 12.017c0 4.425 2.865 8.18 6.839 9.504.5.092.682-.217.682-.483 0-.237-.008-.868-.013-1.703-2.782.605-3.369-1.343-3.369-1.343-.454-1.158-1.11-1.466-1.11-1.466-.908-.62.069-.608.069-.608 1.003.07 1.531 1.032 1.531 1.032.892 1.53 2.341 1.088 2.91.832.092-.647.35-1.088.636-1.338-2.22-.253-4.555-1.113-4.555-4.951 0-1.093.39-1.988 1.029-2.688-.103-.253-.446-1.272.098-2.65 0 0 .84-.27 2.75 1.026A9.564 9.564 0 0112 6.844c.85.004 1.705.115 2.504.337 1.909-1.296 2.747-1.027 2.747-1.027.546 1.379.202 2.398.1 2.651.64.7 1.028 1.595 1.028 2.688 0 3.848-2.339 4.695-4.566 4.943.359.309.678.92.678 1.855 0 1.338-.012 2.419-.012 2.747 0 .268.18.58.688.482A10.019 10.019 0 0022 12.017C22 6.484 17.522 2 12 2z"
                            clip-rule="evenodd"
                          />
                        </svg>
                      </a>
                      <a
                        href="https://x.com/rationalgridai"
                        target="_blank"
                        rel="noopener noreferrer"
                        class="text-white/70 hover:text-white transition-colors"
                        aria-label="X (Twitter)"
                      >
                        <svg class="h-5 w-5" fill="currentColor" viewBox="0 0 24 24">
                          <path d="M18.244 2.25h3.308l-7.227 8.26 8.502 11.24H16.17l-5.214-6.817L4.99 21.75H1.68l7.73-8.835L1.254 2.25H8.08l4.713 6.231zm-1.161 17.52h1.833L7.084 4.126H5.117z" />
                        </svg>
                      </a>
                      <a
                        href="https://www.instagram.com/rationalgrid/"
                        target="_blank"
                        rel="noopener noreferrer"
                        class="text-white/70 hover:text-white transition-colors"
                        aria-label="Instagram"
                      >
                        <svg class="h-6 w-6" fill="currentColor" viewBox="0 0 24 24">
                          <path d="M12 2.163c3.204 0 3.584.012 4.85.07 3.252.148 4.771 1.691 4.919 4.919.058 1.265.069 1.645.069 4.849 0 3.205-.012 3.584-.069 4.849-.149 3.225-1.664 4.771-4.919 4.919-1.266.058-1.644.07-4.85.07-3.204 0-3.584-.012-4.849-.07-3.26-.149-4.771-1.699-4.919-4.92-.058-1.265-.07-1.644-.07-4.849 0-3.204.013-3.583.07-4.849.149-3.227 1.664-4.771 4.919-4.919 1.266-.057 1.645-.069 4.849-.069zM12 0C8.741 0 8.333.014 7.053.072 2.695.272.273 2.69.073 7.052.014 8.333 0 8.741 0 12c0 3.259.014 3.668.072 4.948.2 4.358 2.618 6.78 6.98 6.98C8.333 23.986 8.741 24 12 24c3.259 0 3.668-.014 4.948-.072 4.354-.2 6.782-2.618 6.979-6.98.059-1.28.073-1.689.073-4.948 0-3.259-.014-3.667-.072-4.947-.196-4.354-2.617-6.78-6.979-6.98C15.668.014 15.259 0 12 0zm0 5.838a6.162 6.162 0 100 12.324 6.162 6.162 0 000-12.324zM12 16a4 4 0 110-8 4 4 0 010 8zm6.406-11.845a1.44 1.44 0 100 2.881 1.44 1.44 0 000-2.881z" />
                        </svg>
                      </a>
                      <a
                        href="https://www.linkedin.com/company/rationalgrid-ai/"
                        target="_blank"
                        rel="noopener noreferrer"
                        class="text-white/70 hover:text-white transition-colors"
                        aria-label="LinkedIn"
                      >
                        <svg class="h-6 w-6" fill="currentColor" viewBox="0 0 24 24">
                          <path d="M20.447 20.452h-3.554v-5.569c0-1.328-.027-3.037-1.852-3.037-1.853 0-2.136 1.445-2.136 2.939v5.667H9.351V9h3.414v1.561h.046c.477-.9 1.637-1.85 3.37-1.85 3.601 0 4.267 2.37 4.267 5.455v6.286zM5.337 7.433a2.062 2.062 0 01-2.063-2.065 2.064 2.064 0 112.063 2.065zm1.782 13.019H3.555V9h3.564v11.452zM22.225 0H1.771C.792 0 0 .774 0 1.729v20.542C0 23.227.792 24 1.771 24h20.451C23.2 24 24 23.227 24 22.271V1.729C24 .774 23.2 0 22.222 0h.003z" />
                        </svg>
                      </a>
                    </div>
                  </div>
                </div>
              </section>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp editor_pick_preview_items(curated_grids, _graphs) do
    Enum.map(curated_grids || [], fn item ->
      %{graph: item.graph, author_name: item.author_name}
    end)
  end

  defp quote_text(%{highlight: highlight}) do
    (highlight.selected_text_snapshot || "")
    |> String.trim()
    |> trim_text(360)
  end

  defp quote_note(%{highlight: highlight}) do
    (highlight.note || "")
    |> String.trim()
    |> trim_text(160)
  end

  defp graph_node_count(graph) do
    (graph.data || %{})
    |> Map.get("nodes", [])
    |> Enum.count(fn node -> !Map.get(node, "compound", false) end)
  end

  defp graph_key(graph) do
    graph.slug || Integer.to_string(:erlang.phash2(graph.title || "graph"))
  end

  defp trim_text(text, max_length) when is_binary(text) do
    if String.length(text) > max_length do
      text
      |> String.slice(0, max_length)
      |> String.trim_trailing()
      |> Kernel.<>("...")
    else
      text
    end
  end

  defp home_preview_seed do
    DateTime.utc_now() |> DateTime.to_unix(:second) |> div(60)
  end

  defp preview_curated_grids(items, count, seed) do
    case items || [] do
      [] ->
        []

      grids when length(grids) <= count ->
        grids

      grids ->
        grids
        |> Enum.sort_by(fn item ->
          :erlang.phash2({seed || "home-preview", preview_key(item)})
        end)
        |> Enum.take(count)
    end
  end

  defp preview_key(item), do: item.graph.slug || item.graph.title || ""

  defp partner_pills(items) do
    items
    |> Enum.map(&Map.get(&1, :author_name))
    |> Enum.filter(&author_visible?/1)
    |> Enum.uniq_by(&(String.trim(&1) |> String.downcase()))
  end

  defp author_profile_path(author_name) do
    if author_visible?(author_name), do: ~p"/u/#{author_name}", else: nil
  end

  defp author_visible?(author_name) when is_binary(author_name) do
    normalized = author_name |> String.trim() |> String.downcase()
    normalized != "" and normalized not in ["anonymous", "anon", "-"]
  end

  defp author_visible?(_), do: false

  defp fetch_graphs(search_term, tag, category, limit) do
    cond do
      is_binary(tag) && tag != "" ->
        Dialectic.DbActions.Graphs.list_graphs_by_tag(tag, limit)
        |> Enum.map(fn {g, username} -> {g, 0, username} end)

      category == "deep_dives" ->
        Dialectic.DbActions.Graphs.list_deep_dives(limit)
        |> Enum.map(fn {g, username} -> {g, 0, username} end)

      category == "seedlings" ->
        Dialectic.DbActions.Graphs.list_seedlings(limit)
        |> Enum.map(fn {g, username} -> {g, 0, username} end)

      true ->
        Dialectic.DbActions.Graphs.all_graphs_with_notes(search_term, limit: limit)
    end
  end

  defp table_tag_color_class(tag) do
    colors = [
      "bg-rose-50 text-rose-700 ring-rose-600/20",
      "bg-orange-50 text-orange-700 ring-orange-600/20",
      "bg-amber-50 text-amber-700 ring-amber-600/20",
      "bg-lime-50 text-lime-700 ring-lime-600/20",
      "bg-green-50 text-green-700 ring-green-600/20",
      "bg-emerald-50 text-emerald-700 ring-emerald-600/20",
      "bg-teal-50 text-teal-700 ring-teal-600/20",
      "bg-cyan-50 text-cyan-700 ring-cyan-600/20",
      "bg-sky-50 text-sky-700 ring-sky-600/20",
      "bg-blue-50 text-blue-700 ring-blue-600/20",
      "bg-indigo-50 text-indigo-700 ring-indigo-600/20",
      "bg-violet-50 text-violet-700 ring-violet-600/20",
      "bg-purple-50 text-purple-700 ring-purple-600/20",
      "bg-fuchsia-50 text-fuchsia-700 ring-fuchsia-600/20",
      "bg-pink-50 text-pink-700 ring-pink-600/20"
    ]

    idx = :erlang.phash2(tag, length(colors))
    Enum.at(colors, idx)
  end

  defp graph_dom_id(graph, prefix) do
    suffix = graph.slug || Integer.to_string(:erlang.phash2(graph.title || "graph"))
    prefix <> "-" <> suffix
  end

  defp page_title(search, tag, category) do
    cond do
      is_binary(tag) and tag != "" -> "Tagged: #{tag}"
      category == "deep_dives" -> "Deep Dives"
      category == "seedlings" -> "Seedlings"
      is_binary(search) and search != "" -> "Search: #{search}"
      true -> "RationalGrid"
    end
  end
end
