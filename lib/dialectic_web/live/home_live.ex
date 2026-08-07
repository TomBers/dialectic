defmodule DialecticWeb.HomeLive do
  use DialecticWeb, :live_view
  alias Dialectic.Accounts.User
  alias Dialectic.DbActions.Graphs
  alias Dialectic.Graph.GraphActions
  alias Dialectic.Graph.Vertex
  alias DialecticWeb.Utils.UserUtils
  import DialecticWeb.GridCardComp
  require Logger

  on_mount {DialecticWeb.UserAuth, :mount_current_user}

  @impl true
  def mount(params, session, socket) do
    socket =
      assign(socket,
        loading_graph: nil,
        llm_actor_id: session["llm_actor_id"] || "home:#{socket.id}"
      )

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
       limit: 12,
       generating: MapSet.new(),
       user: user,
       form: to_form(changeset),
       prompt_mode: prompt_mode,
       ask_question: true,
       graph_id: nil,
       focus_new_grid: params["focus"] == "grid",
       preview_seed: home_preview_seed(),
       curated_grids: [],
       all_curated_grids: [],
       editor_pick_grids: [],
       featured_grids: [],
       quick_tags: [],
       page_description:
         "Ask a question, map the answer, and challenge any branch while keeping its original context with RationalGrid."
     )}
  end

  @impl true
  def handle_params(params, _url, socket) do
    search_term = Map.get(params, "search", "")
    tag = Map.get(params, "tag")
    category = Map.get(params, "category")
    limit = 12

    graphs = fetch_graphs(search_term, tag, category, limit)
    popular_tags = Graphs.list_popular_tags()
    # Fetch more items than needed to have a pool for randomization
    all_curated_grids = Graphs.list_curated_grids("curated", 20)
    all_featured_grids = Graphs.list_curated_grids("featured", 20)

    curated_grids = preview_curated_grids(all_curated_grids, 3, socket.assigns.preview_seed)
    editor_pick_grids = editor_pick_grids(all_curated_grids, 2)

    featured_grids =
      home_featured_grids(all_featured_grids, curated_grids, socket.assigns.preview_seed)

    {:noreply,
     assign(socket,
       search_term: search_term,
       active_tag: tag,
       active_category: category,
       graphs: graphs,
       popular_tags: popular_tags,
       curated_grids: curated_grids,
       all_curated_grids: all_curated_grids,
       editor_pick_grids: editor_pick_grids,
       featured_grids: featured_grids,
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

  defp create_graph_task(title, answer, prompt_mode, current_user, actor_id, parent_pid) do
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
      actor_id: actor_id,
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
            actor_id = socket.assigns.llm_actor_id

            socket
            |> assign(:loading_graph, %{title: title, status: "Initializing...", steps: []})
            |> start_async(:create_graph_flow, fn ->
              create_graph_task(title, answer, prompt_mode, current_user, actor_id, parent_pid)
            end)

          existing_graph ->
            redirect(socket, to: graph_editor_path(existing_graph))
        end
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-[#f4f1e9] font-sans text-slate-950 antialiased">
      <%= if @loading_graph do %>
        <div class="fixed inset-0 z-50 flex items-center justify-center bg-slate-950/95 px-4">
          <div class="w-full max-w-md border border-slate-700 bg-slate-900 p-6 text-white shadow-2xl sm:p-8">
            <div class="flex items-start gap-4">
              <span class="mt-1 h-3 w-3 shrink-0 animate-pulse bg-teal-300"></span>
              <div class="min-w-0">
                <p class="text-xs font-semibold uppercase tracking-[0.18em] text-teal-300">
                  Building your grid
                </p>
                <h3 class="mt-2 font-serif text-2xl font-semibold">{@loading_graph.title}</h3>
                <p class="mt-2 text-sm text-slate-300">{@loading_graph.status}</p>
              </div>
            </div>
            <div class="mt-6 border-t border-slate-700 pt-4">
              <%= for step <- Enum.reverse(@loading_graph.steps) |> Enum.take(3) do %>
                <div class="mt-2 flex items-center gap-2 text-sm text-slate-300">
                  <.icon name="hero-check" class="h-4 w-4 text-teal-300" />
                  {step}
                </div>
              <% end %>
            </div>
          </div>
        </div>
      <% end %>

      <section
        id="home-video-hero"
        class="relative isolate min-h-[72svh] overflow-hidden border-b border-slate-700 bg-slate-950 text-white sm:min-h-[78svh]"
      >
        <video
          id="home-video-hero-player"
          phx-hook="VideoPlayback"
          phx-update="ignore"
          data-playback-rate="4.5"
          class="absolute inset-0 -z-20 h-full w-full object-cover opacity-35"
          autoplay={true}
          muted={true}
          playsinline={true}
          preload="metadata"
          aria-hidden="true"
        >
          <source src={~p"/images/FractalBranchingTree.mp4"} type="video/mp4" />
        </video>
        <div class="absolute inset-0 -z-10 bg-slate-950/70"></div>

        <div class="mx-auto grid min-h-[72svh] w-full max-w-7xl items-center gap-12 px-5 py-16 sm:min-h-[78svh] sm:px-8 lg:grid-cols-[minmax(0,1.12fr)_minmax(22rem,0.72fr)] lg:px-10">
          <div class="max-w-4xl">
            <p class="border-l-2 border-teal-300 pl-3 text-xs font-semibold uppercase tracking-[0.2em] text-teal-200">
              A branching workspace for questions
            </p>
            <h1 class="mt-6 text-balance font-serif text-5xl font-semibold leading-[0.98] tracking-tight text-white sm:text-7xl lg:text-[5.4rem]">
              Ask a question. Map the answer. Challenge any branch.
            </h1>
            <p class="mt-6 max-w-2xl text-pretty text-base leading-7 text-slate-200 sm:text-xl sm:leading-8">
              RationalGrid keeps every question, answer, objection, and source in one visible map—so
              you can see how the thinking developed and choose where to go next.
            </p>
            <div class="mt-8 flex flex-wrap items-center gap-3">
              <.link
                href="#start-here"
                class="inline-flex items-center gap-2 rounded-md bg-teal-300 px-5 py-3 text-sm font-semibold text-slate-950 transition hover:bg-teal-200"
              >
                Start with a question <.icon name="hero-arrow-down" class="h-4 w-4" />
              </.link>
              <.link
                navigate={~p"/g/what-is-the-collective-subconscious-637e9a"}
                class="inline-flex items-center gap-2 border-b border-slate-400 px-1 py-2 text-sm font-semibold text-white transition hover:border-teal-300 hover:text-teal-200"
              >
                Read an example grid <.icon name="hero-arrow-up-right" class="h-4 w-4" />
              </.link>
            </div>
          </div>

          <div class="hidden lg:block" aria-hidden="true">
            <div class="mx-auto max-w-md">
              <div class="border-l-4 border-sky-400 bg-slate-900/90 px-5 py-4 shadow-xl">
                <p class="text-[10px] font-bold uppercase tracking-[0.2em] text-sky-300">Question</p>
                <p class="mt-1 font-serif text-xl text-white">
                  What makes an explanation convincing?
                </p>
              </div>
              <div class="mx-auto h-9 w-px bg-slate-500"></div>
              <div class="relative grid grid-cols-2 gap-8 border-t border-slate-500 pt-9">
                <div class="absolute left-1/4 top-0 h-9 w-px bg-slate-500"></div>
                <div class="absolute right-1/4 top-0 h-9 w-px bg-slate-500"></div>
                <div class="border-l-4 border-emerald-400 bg-slate-900/90 px-4 py-3">
                  <p class="text-[10px] font-bold uppercase tracking-[0.2em] text-emerald-300">
                    Answer
                  </p>
                  <p class="mt-1 text-sm font-medium text-white">Evidence and inference</p>
                </div>
                <div class="border-l-4 border-amber-400 bg-slate-900/90 px-4 py-3">
                  <p class="text-[10px] font-bold uppercase tracking-[0.2em] text-amber-300">
                    Challenge
                  </p>
                  <p class="mt-1 text-sm font-medium text-white">Which assumption fails?</p>
                </div>
              </div>
              <div class="ml-auto mr-[12%] h-9 w-px bg-slate-500"></div>
              <div class="ml-auto w-[58%] border-l-4 border-violet-400 bg-slate-900/90 px-4 py-3">
                <p class="text-[10px] font-bold uppercase tracking-[0.2em] text-violet-300">Source</p>
                <p class="mt-1 text-sm font-medium text-white">Keep the evidence attached</p>
              </div>
            </div>
          </div>
        </div>
      </section>

      <section id="start-here" class="border-b border-stone-300 bg-[#f4f1e9]">
        <div class="mx-auto grid w-full max-w-7xl gap-10 px-5 py-12 sm:px-8 sm:py-16 lg:grid-cols-[minmax(18rem,0.72fr)_minmax(0,1.28fr)] lg:px-10">
          <div>
            <p class="text-xs font-semibold uppercase tracking-[0.2em] text-teal-800">Start here</p>
            <h2 class="mt-3 max-w-xl font-serif text-4xl font-semibold leading-tight tracking-tight sm:text-5xl">
              Begin with the question that will not fit in a chat box.
            </h2>
            <p class="mt-4 max-w-lg text-base leading-7 text-slate-700">
              The first answer becomes a map. Select any part of it to ask a follow-up, test an
              assumption, add a comment, or attach a source.
            </p>
            <.link
              navigate={~p"/intro/how"}
              class="mt-6 inline-flex items-center gap-2 border-b border-slate-500 pb-1 text-sm font-semibold text-slate-900 transition hover:border-teal-700 hover:text-teal-800"
            >
              How a grid works <.icon name="hero-arrow-right" class="h-4 w-4" />
            </.link>
          </div>

          <div>
            <div
              id="home-start-panel"
              class="border border-stone-300 border-l-4 border-l-teal-700 bg-white p-4 shadow-sm sm:p-6"
            >
              <div class="mb-4 flex items-baseline justify-between gap-4 border-b border-stone-200 pb-3">
                <h3 class="font-serif text-xl font-semibold text-slate-950">
                  What would you like to understand?
                </h3>
                <span class="text-xs font-medium text-slate-500">About two minutes</span>
              </div>
              <.live_component
                module={DialecticWeb.NewIdeaFormComp}
                id="new-idea-form"
                form={@form}
                placeholder="What do you want to understand?"
                submit_label="Continue"
                autofocus={@focus_new_grid}
              />
            </div>

            <div id="home-start-steps" class="mt-7 grid gap-4 text-sm sm:grid-cols-3">
              <article class="border-t-4 border-sky-500 pt-3">
                <span class="font-mono text-xs font-bold text-sky-800">01</span>
                <h3 class="mt-1 font-semibold text-slate-950">Start with a question</h3>
                <p class="mt-1 leading-5 text-slate-600">Bring a question, idea, or source.</p>
              </article>
              <article class="border-t-4 border-emerald-600 pt-3">
                <span class="font-mono text-xs font-bold text-emerald-800">02</span>
                <h3 class="mt-1 font-semibold text-slate-950">Branch into follow-ups</h3>
                <p class="mt-1 leading-5 text-slate-600">Ask from any point in the answer.</p>
              </article>
              <article class="border-t-4 border-amber-500 pt-3">
                <span class="font-mono text-xs font-bold text-amber-800">03</span>
                <h3 class="mt-1 font-semibold text-slate-950">Keep the context</h3>
                <p class="mt-1 leading-5 text-slate-600">
                  Each answer keeps its parent’s context.
                </p>
              </article>
            </div>
          </div>
        </div>
      </section>

      <section id="home-product-preview" class="border-b border-slate-700 bg-slate-950 text-white">
        <div class="mx-auto grid w-full max-w-7xl gap-10 px-5 py-12 sm:px-8 sm:py-16 lg:grid-cols-[minmax(20rem,0.72fr)_minmax(0,1.28fr)] lg:items-center lg:px-10">
          <div>
            <p class="text-xs font-semibold uppercase tracking-[0.2em] text-teal-300">
              One workspace, three views
            </p>
            <h2 class="mt-3 font-serif text-4xl font-semibold tracking-tight sm:text-5xl">
              Read the thread. Edit the map. Present the path.
            </h2>
            <p class="mt-4 text-base leading-7 text-slate-300">
              The structure stays intact as you move between a focused reader, the full branching
              canvas, and a guided presentation.
            </p>
            <dl class="mt-7 divide-y divide-slate-700 border-y border-slate-700 text-sm">
              <div class="grid grid-cols-[4.5rem_1fr] gap-4 py-3">
                <dt class="font-semibold text-sky-300">Read</dt>
                <dd class="text-slate-300">Follow one chain without losing the wider outline.</dd>
              </div>
              <div class="grid grid-cols-[4.5rem_1fr] gap-4 py-3">
                <dt class="font-semibold text-emerald-300">Edit</dt>
                <dd class="text-slate-300">Open any node and branch from that exact context.</dd>
              </div>
              <div class="grid grid-cols-[4.5rem_1fr] gap-4 py-3">
                <dt class="font-semibold text-amber-300">Present</dt>
                <dd class="text-slate-300">Choose a route through the grid for someone else.</dd>
              </div>
            </dl>
          </div>

          <div class="border border-slate-700 bg-black p-2 shadow-2xl sm:p-3">
            <iframe
              id="home-example-video"
              class="aspect-video w-full"
              src="https://www.youtube.com/embed/nZOqbspGPfY?si=iOZEER4hWd31G157"
              title="RationalGrid product video"
              loading="lazy"
              frameborder="0"
              allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
              referrerpolicy="strict-origin-when-cross-origin"
              allowfullscreen
            >
            </iframe>
          </div>
        </div>
      </section>

      <section id="popular-grids" class="border-b border-stone-300 bg-white">
        <div class="mx-auto w-full max-w-7xl px-5 py-12 sm:px-8 sm:py-16 lg:px-10">
          <div class="flex flex-col gap-5 border-b border-slate-300 pb-6 sm:flex-row sm:items-end sm:justify-between">
            <div class="max-w-3xl">
              <p class="text-xs font-semibold uppercase tracking-[0.2em] text-teal-800">
                Public grids
              </p>
              <h2 class="mt-3 font-serif text-4xl font-semibold tracking-tight sm:text-5xl">
                <%= if @search_term != "" do %>
                  Results for “{@search_term}”
                <% else %>
                  Read a grid before you make one.
                <% end %>
              </h2>
              <p class="mt-3 max-w-2xl text-base leading-7 text-slate-600">
                These are real lines of inquiry. Open one, inspect the branches, and continue from
                the point that interests you.
              </p>
            </div>
            <.link
              id="home-community-grids-link"
              navigate={~p"/community"}
              class="inline-flex shrink-0 items-center gap-2 rounded-md bg-slate-950 px-4 py-2.5 text-sm font-semibold text-white transition hover:bg-slate-800"
            >
              Explore all community grids <.icon name="hero-arrow-right" class="h-4 w-4" />
            </.link>
          </div>

          <%= if @featured_grids != [] do %>
            <section id="curated" class="mt-8">
              <.curated_grid_section
                items={@featured_grids}
                icon="hero-users"
                icon_class="text-teal-800"
                title="Partner grids"
                pills={partner_pills(@featured_grids)}
                id_prefix="featured"
                section_class=""
                icon_wrap_class="border-teal-700 text-teal-800"
              />
            </section>
          <% end %>

          <%= if @graphs == [] do %>
            <div class="mt-8 border border-dashed border-slate-300 bg-stone-50 p-8 text-sm text-slate-600">
              No public grids match this search yet.
            </div>
          <% else %>
            <div id="home-graph-card-list" class="mt-8 grid gap-5 md:grid-cols-2 xl:grid-cols-3">
              <%= for {graph, _count, username} <- @graphs do %>
                <.grid_card
                  graph={graph}
                  author_name={username}
                  author_marker="@"
                  id={graph_dom_id(graph, "home-card-graph")}
                  variant={:compact}
                  tag_limit={3}
                />
              <% end %>
            </div>
          <% end %>

          <%= if @curated_grids != [] do %>
            <div class="mt-10 border-t border-slate-300 pt-6">
              <div class="flex items-baseline justify-between gap-4">
                <h3 class="font-serif text-2xl font-semibold text-slate-950">
                  Three useful starting points
                </h3>
                <span class="hidden text-sm text-slate-500 sm:inline">
                  Selected from the community
                </span>
              </div>
              <div id="home-community-grid-list" class="mt-4 grid gap-5 md:grid-cols-3">
                <%= for item <- @curated_grids do %>
                  <.grid_card
                    graph={item.graph}
                    author_name={item.author_name}
                    author_marker="@"
                    id={graph_dom_id(item.graph, "home-community-grid")}
                    variant={:compact}
                    label="Curated grid"
                    tag_limit={3}
                  />
                <% end %>
              </div>
            </div>
          <% end %>
        </div>
      </section>

      <section id="home-profile-section" class="border-b border-slate-700 bg-slate-900 text-white">
        <div class="mx-auto grid w-full max-w-7xl gap-10 px-5 py-12 sm:px-8 sm:py-16 lg:grid-cols-[minmax(0,0.9fr)_minmax(22rem,0.65fr)] lg:items-center lg:px-10">
          <div>
            <p class="text-xs font-semibold uppercase tracking-[0.2em] text-teal-300">
              Public profiles
            </p>
            <h2 class="mt-3 max-w-2xl font-serif text-4xl font-semibold tracking-tight sm:text-5xl">
              Publish a trail others can follow.
            </h2>
            <p class="mt-4 max-w-2xl text-base leading-7 text-slate-300">
              A profile collects your public grids, highlights, and topics. Other people can inspect
              your reasoning, follow your work, or start a new branch from it.
            </p>
            <div class="mt-7 flex flex-wrap gap-3">
              <%= if @current_user do %>
                <.link
                  navigate={~p"/u/#{User.effective_username(@current_user)}"}
                  class="inline-flex items-center gap-2 rounded-md bg-teal-300 px-4 py-2.5 text-sm font-semibold text-slate-950 transition hover:bg-teal-200"
                >
                  <.icon name="hero-user-circle" class="h-4 w-4" /> View my profile
                </.link>
              <% else %>
                <.link
                  navigate={~p"/users/register"}
                  class="inline-flex items-center gap-2 rounded-md bg-teal-300 px-4 py-2.5 text-sm font-semibold text-slate-950 transition hover:bg-teal-200"
                >
                  <.icon name="hero-user-plus" class="h-4 w-4" /> Create your profile
                </.link>
              <% end %>
              <.link
                navigate={~p"/community"}
                class="inline-flex items-center gap-2 border-b border-slate-400 px-1 py-2 text-sm font-semibold text-white transition hover:border-teal-300 hover:text-teal-200"
              >
                Browse people and grids <.icon name="hero-arrow-right" class="h-4 w-4" />
              </.link>
            </div>
          </div>

          <div class="border border-slate-600 bg-slate-950">
            <div class="h-20 overflow-hidden border-b border-slate-700 bg-orange-500">
              <img
                src={~p"/images/profile-banners/flat-mountains.svg"}
                alt=""
                class="h-full w-full object-cover"
                aria-hidden="true"
              />
            </div>
            <div class="p-5">
              <div class="flex items-center gap-3">
                <img
                  src={~p"/images/tom.webp"}
                  alt="TomBers's avatar"
                  class="h-14 w-14 rounded-full border-2 border-white object-cover"
                />
                <div>
                  <p class="font-serif text-2xl font-semibold">TomBers</p>
                  <p class="text-sm text-slate-400">Makes MuDG</p>
                </div>
              </div>
              <p class="mt-5 border-l-2 border-teal-300 pl-3 text-sm leading-6 text-slate-300">
                Philosophy, Sociology, and History across 127 public grids.
              </p>
              <div class="mt-5 grid grid-cols-3 border-y border-slate-700 py-3 text-center">
                <div>
                  <p class="text-xl font-semibold">127</p>
                  <p class="text-[10px] uppercase tracking-[0.16em] text-slate-400">grids</p>
                </div>
                <div class="border-x border-slate-700">
                  <p class="text-xl font-semibold">1425</p>
                  <p class="text-[10px] uppercase tracking-[0.16em] text-slate-400">ideas</p>
                </div>
                <div>
                  <p class="text-xl font-semibold">2</p>
                  <p class="text-[10px] uppercase tracking-[0.16em] text-slate-400">followers</p>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      <footer class="bg-slate-950 text-slate-300">
        <div class="mx-auto flex w-full max-w-7xl flex-col gap-5 px-5 py-8 sm:flex-row sm:items-center sm:justify-between sm:px-8 lg:px-10">
          <div class="flex items-center gap-3">
            <img src={~p"/images/favicon.webp"} alt="RationalGrid" class="h-7 w-7" />
            <div>
              <p class="font-semibold text-white">RationalGrid</p>
              <p class="text-xs text-slate-500">Questions stay connected to what came before.</p>
            </div>
          </div>
          <nav aria-label="Homepage footer" class="flex flex-wrap gap-x-5 gap-y-2 text-sm">
            <.link navigate={~p"/intro/how"} class="hover:text-white">Guide</.link>
            <.link navigate={~p"/about"} class="hover:text-white">About</.link>
            <.link navigate={~p"/community"} class="hover:text-white">Community</.link>
            <.link navigate={~p"/gallery"} class="hover:text-white">Gallery</.link>
            <.link
              href="https://github.com/TomBers/dialectic"
              target="_blank"
              rel="noopener noreferrer"
              class="hover:text-white"
            >
              GitHub
            </.link>
          </nav>
        </div>
      </footer>
    </div>
    """
  end

  defp curated_grid_section(assigns) do
    assigns =
      assigns
      |> assign_new(:pills, fn -> [] end)
      |> assign(:card_label, curated_card_label(assigns.title))

    ~H"""
    <section class="w-full min-w-0 border border-slate-300 bg-[#f4f1e9]">
      <div class="h-full">
        <div class="p-4 sm:p-5">
          <div class="mb-5 flex flex-col gap-3 border-b border-slate-300 pb-4 sm:flex-row sm:items-center sm:justify-between">
            <div class="flex items-center gap-2">
              <span class={[
                "inline-flex h-9 w-9 items-center justify-center border",
                @icon_wrap_class
              ]}>
                <.icon name={@icon} class={"h-5 w-5 " <> @icon_class} />
              </span>
              <div class="min-w-0">
                <p class="text-[11px] font-semibold uppercase tracking-[0.18em] text-slate-500">
                  Curated
                </p>
                <h2 class="text-lg font-semibold tracking-tight text-slate-950">
                  {@title}
                </h2>
              </div>
            </div>
            <%= if @pills != [] do %>
              <div class="flex flex-wrap gap-1.5 sm:justify-end">
                <span
                  :for={pill <- @pills}
                  class="inline-flex items-center border-l border-slate-400 pl-2 text-[11px] font-medium text-slate-600"
                >
                  {pill}
                </span>
              </div>
            <% end %>
          </div>
          <div id={"#{@id_prefix}-grids-list"} class="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
            <%= for item <- @items do %>
              <.grid_card
                graph={item.graph}
                author_name={item.author_name}
                author_marker="@"
                id={@id_prefix <> "-" <> (item.graph.slug || "t-" <> Integer.to_string(:erlang.phash2(item.graph.title || "")))}
                label={Map.get(item, :card_label, @card_label)}
                tag_limit={3}
              />
            <% end %>
          </div>
        </div>
      </div>
    </section>
    """
  end

  defp home_preview_seed do
    System.unique_integer([:positive])
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

  defp home_featured_grids(featured, curated, seed) do
    featured = preview_curated_grids(featured, 2, seed)

    case {featured, curated} do
      {featured, [curated_grid | _]} when length(featured) >= 2 ->
        Enum.take(featured, 2) ++ [Map.put(curated_grid, :card_label, "Curated grid")]

      {featured, curated} ->
        preview_curated_grids(featured ++ curated, 3, seed)
    end
  end

  defp editor_pick_grids(items, limit) do
    items = items || []
    {deep_dives, other_grids} = Enum.split_with(items, &(home_graph_node_count(&1.graph) >= 20))

    (deep_dives ++ other_grids)
    |> Enum.take(limit)
  end

  defp home_graph_node_count(%{node_count: count}) when is_integer(count), do: count

  defp home_graph_node_count(graph) do
    nodes =
      (Map.get(graph, :data) || %{})
      |> then(fn data -> Map.get(data, "nodes") || Map.get(data, :nodes) || [] end)

    if is_list(nodes) do
      Enum.count(nodes, fn node ->
        compound? = Map.get(node, "compound", Map.get(node, :compound, false))
        compound? != true
      end)
    else
      0
    end
  end

  defp curated_card_label("Partner grids"), do: "Partner grid"
  defp curated_card_label(_title), do: "Curated grid"

  defp partner_pills(items) do
    items
    |> Enum.map(&Map.get(&1, :author_name))
    |> Enum.filter(&author_visible?/1)
    |> Enum.uniq_by(&(String.trim(&1) |> String.downcase()))
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
