defmodule DialecticWeb.HomeLive do
  use DialecticWeb, :live_view
  alias Dialectic.DbActions.Graphs
  alias Dialectic.Graph.GraphActions
  alias Dialectic.Graph.Vertex
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
       curated_grids: [],
       featured_grids: []
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
    curated_grids = Graphs.list_curated_grids("curated", 6)
    featured_grids = Graphs.list_curated_grids("featured", 6)

    {:noreply,
     assign(socket,
       search_term: search_term,
       active_tag: tag,
       active_category: category,
       graphs: graphs,
       popular_tags: popular_tags,
       curated_grids: curated_grids,
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
    title = Graphs.sanitize_title(answer)
    mode_param = Map.get(params, "mode")
    socket = if mode_param, do: assign(socket, prompt_mode: mode_param), else: socket

    cond do
      socket.assigns.loading_graph != nil ->
        {:noreply, socket}

      title == "untitled-idea" ->
        {:noreply, put_flash(socket, :error, "Please enter a question or topic.")}

      true ->
        existing_graph = Graphs.get_graph_by_title(title)

        if existing_graph do
          {:noreply, redirect(socket, to: graph_path(existing_graph))}
        else
          parent_pid = self()
          prompt_mode = socket.assigns[:prompt_mode]
          current_user = socket.assigns[:current_user]

          socket =
            socket
            |> assign(:loading_graph, %{title: title, status: "Initializing...", steps: []})
            |> start_async(:create_graph_flow, fn ->
              create_graph_task(title, answer, prompt_mode, current_user, parent_pid)
            end)

          {:noreply, socket}
        end
    end
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
        {:noreply, redirect(socket, to: graph_path(graph))}
    end
  end

  def handle_async(:create_graph_flow, {:ok, _}, socket) do
    {:noreply, put_flash(socket, :error, "Failed to create grid") |> assign(:loading_graph, nil)}
  end

  def handle_async(:create_graph_flow, {:exit, reason}, socket) do
    # Log the crash reason if needed
    Logger.error("Grid creation crashed: #{inspect(reason)}")

    {:noreply,
     put_flash(socket, :error, "Grid creation failed. Please try again.")
     |> assign(:loading_graph, nil)}
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
      Enum.map(socket.assigns.graphs, fn {g, c} ->
        if g.title == title do
          {Map.put(g, :tags, tags), c}
        else
          {g, c}
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

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-[calc(100vh-4rem)] w-screen bg-slate-950 text-white">
      <div class="relative min-h-[calc(100vh-4rem)] w-screen overflow-hidden">
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
        
    <!-- Background Video with Overlay (full-bleed) -->
        <div class="absolute inset-0 z-0">
          <video
            autoplay
            muted
            playsinline
            preload="none"
            class="absolute inset-0 h-full w-full object-cover opacity-40"
            aria-hidden="true"
          >
            <source src={~p"/images/FractalBranchingTree.mp4"} type="video/mp4" />
          </video>
          <div class="absolute inset-0 bg-gradient-to-r from-[#3a0ca3]/90 to-[#4361ee]/90 mix-blend-multiply">
          </div>
        </div>
        
    <!-- Make the hero content scroll within the viewport naturally -->
        <div class="relative z-10 mx-auto max-w-7xl px-4 sm:px-6 pt-8 sm:pt-14 pb-6 sm:pb-10 min-h-[calc(100vh-4rem)]">
          <div class="flex flex-col gap-6 sm:gap-10 items-stretch">
            <!-- Top: Create new idea (primary action, centered stack with breathing room) -->
            <section class="w-full">
              <div class="mx-auto w-full max-w-3xl">
                <div class="flex flex-col items-center text-center gap-5 sm:gap-7">
                  <div class="space-y-2 sm:space-y-4">
                    <h1 class="text-3xl font-bold tracking-tight text-white sm:text-5xl">
                      RationalGrid
                    </h1>
                    <p class="text-base sm:text-xl font-medium text-indigo-100 px-2 sm:px-0">
                      A shared AI-powered grid; explore ideas deeply, structure thinking, and sharpen arguments.
                    </p>
                  </div>

                  <div class="w-full bg-white/10 backdrop-blur-md rounded-2xl shadow-xl border border-white/15 p-4 sm:p-6">
                    <.live_component
                      module={DialecticWeb.NewIdeaFormComp}
                      id="new-idea-form"
                      form={@form}
                    />
                  </div>

                  <div class="flex flex-col sm:flex-row items-stretch sm:items-center justify-center gap-2 sm:gap-3 text-sm font-semibold w-full px-1 sm:px-0">
                    <.link
                      navigate={~p"/inspiration"}
                      class={[
                        "inline-flex items-center justify-center gap-2 rounded-xl px-4 py-3",
                        "bg-white text-[#3a0ca3] shadow-lg ring-1 ring-white/30",
                        "hover:bg-white/95 hover:shadow-xl transition",
                        "focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-white"
                      ]}
                    >
                      <.icon name="hero-sparkles" class="w-5 h-5" /> Inspire me
                    </.link>

                    <.link
                      navigate={~p"/intro/how"}
                      class={[
                        "inline-flex items-center justify-center gap-2 rounded-xl px-4 py-3",
                        "bg-white/10 text-white shadow-lg ring-1 ring-white/25 backdrop-blur-md",
                        "hover:bg-white/15 hover:shadow-xl transition",
                        "focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-white"
                      ]}
                    >
                      <.icon name="hero-book-open" class="w-5 h-5" /> Read the guide
                    </.link>
                  </div>

                  <div class="h-3 sm:h-10" />
                </div>
              </div>
            </section>

            <%!-- Curated & Featured Grids – 2-column on desktop --%>
            <%= if @curated_grids != [] or @featured_grids != [] do %>
              <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 w-full">
                <%= if @curated_grids != [] do %>
                  <.curated_grid_section
                    items={@curated_grids}
                    icon="hero-star"
                    icon_class="text-amber-300"
                    title="Curated Grids"
                    description="Hand-picked grids showcasing great thinking and exploration."
                    id_prefix="curated"
                    author_label="by"
                  />
                <% end %>
                <%= if @featured_grids != [] do %>
                  <.curated_grid_section
                    items={@featured_grids}
                    icon="hero-users"
                    icon_class="text-indigo-300"
                    title="Featured by Partners"
                    description="Grids curated by our invited partners and thought leaders."
                    id_prefix="featured"
                    author_label="by"
                  />
                <% end %>
              </div>
            <% end %>
            
    <!-- Below: All ideas (full-width on desktop, uses available space) -->
            <section class="w-full" id="explore">
              <div class="rounded-2xl border border-white/15 bg-white/10 backdrop-blur-md shadow-xl">
                <div class="p-4 sm:p-6">
                  <div class="flex flex-col gap-3 sm:gap-4 sm:flex-row sm:items-center sm:justify-between">
                    <h2 class="text-lg sm:text-2xl font-semibold tracking-tight text-white">
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
                          All Ideas
                      <% end %>
                    </h2>

                    <div class="w-full sm:w-80">
                      <form
                        phx-change="search"
                        phx-submit="search"
                        class="flex relative"
                        onsubmit="return false;"
                      >
                        <input
                          type="text"
                          name="search"
                          value={@search_term}
                          phx-debounce="300"
                          placeholder="Search ideas..."
                          class="w-full px-4 py-2.5 sm:py-2 rounded-l-md border border-white/15 bg-white/10 text-white placeholder:text-white/60 focus:outline-none focus:ring-2 focus:ring-white/30 text-base"
                          autocomplete="off"
                        />
                        <%= if @search_term && @search_term != "" do %>
                          <button
                            type="button"
                            phx-click="search"
                            phx-value-search=""
                            class="absolute right-12 top-0 bottom-0 flex items-center pr-3 text-white/70 hover:text-white transition-colors"
                          >
                            <svg
                              xmlns="http://www.w3.org/2000/svg"
                              class="h-5 w-5"
                              fill="none"
                              viewBox="0 0 24 24"
                              stroke="currentColor"
                            >
                              <path
                                stroke-linecap="round"
                                stroke-linejoin="round"
                                stroke-width="2"
                                d="M6 18L18 6M6 6l12 12"
                              />
                            </svg>
                          </button>
                        <% end %>
                        <button
                          type="button"
                          class="bg-white/20 text-white px-4 py-2 rounded-r-md hover:bg-white/25 transition border border-white/15 border-l-0"
                        >
                          <svg
                            xmlns="http://www.w3.org/2000/svg"
                            class="h-5 w-5"
                            fill="none"
                            viewBox="0 0 24 24"
                            stroke="currentColor"
                          >
                            <path
                              stroke-linecap="round"
                              stroke-linejoin="round"
                              stroke-width="2"
                              d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"
                            />
                          </svg>
                        </button>
                      </form>
                    </div>
                  </div>

                  <div class="mt-4 sm:mt-5 space-y-3 sm:space-y-4">
                    <div class="flex flex-wrap gap-1.5 sm:gap-2">
                      <.link
                        patch={~p"/"}
                        class={[
                          "px-4 py-2 sm:px-3 sm:py-1.5 rounded-full text-sm font-medium transition-colors",
                          (!@active_category && !@active_tag && @search_term == "" &&
                             "bg-white text-[#3a0ca3]") ||
                            "bg-white/10 text-white hover:bg-white/15 border border-white/10"
                        ]}
                      >
                        All
                      </.link>
                      <.link
                        patch={~p"/?category=deep_dives"}
                        class={[
                          "px-4 py-2 sm:px-3 sm:py-1.5 rounded-full text-sm font-medium transition-colors",
                          (@active_category == "deep_dives" && "bg-white text-[#3a0ca3]") ||
                            "bg-white/10 text-white hover:bg-white/15 border border-white/10"
                        ]}
                      >
                        Deep Dives
                      </.link>
                      <.link
                        patch={~p"/?category=seedlings"}
                        class={[
                          "px-4 py-2 sm:px-3 sm:py-1.5 rounded-full text-sm font-medium transition-colors",
                          (@active_category == "seedlings" && "bg-white text-[#3a0ca3]") ||
                            "bg-white/10 text-white hover:bg-white/15 border border-white/10"
                        ]}
                      >
                        Seedlings
                      </.link>
                    </div>

                    <%= if @popular_tags != [] do %>
                      <div class="flex flex-col sm:flex-row sm:flex-wrap items-start sm:items-center gap-2">
                        <span class="text-sm text-white/70 sm:mr-2 flex-shrink-0">
                          Popular topics:
                        </span>
                        <div class="flex overflow-x-auto scrollbar-hide sm:flex-wrap gap-2 w-full sm:w-auto pb-1 sm:pb-0 -mb-1 sm:mb-0">
                          <%= for {tag, count} <- @popular_tags do %>
                            <.link
                              patch={~p"/?tag=#{tag}"}
                              class={[
                                "text-xs font-medium px-3 py-1.5 sm:px-2.5 sm:py-0.5 rounded border transition-colors whitespace-nowrap flex-shrink-0",
                                (@active_tag == tag && "bg-white text-[#3a0ca3] border-white") ||
                                  "bg-white/10 text-white border-white/15 hover:border-white/30 hover:bg-white/15"
                              ]}
                            >
                              #{tag} <span class="text-white/60 ml-0.5">({count})</span>
                            </.link>
                          <% end %>
                        </div>
                      </div>
                    <% end %>
                  </div>
                </div>

                <div class="border-t border-white/10">
                  <div class="p-4 sm:p-6">
                    <div class="columns-1 sm:columns-2 lg:columns-3 gap-4 sm:gap-6 space-y-4 sm:space-y-6">
                      <%= for {g, count, author_username} <- @graphs do %>
                        <div class="break-inside-avoid">
                          <DialecticWeb.PageHtml.GraphComp.render
                            title={g.title}
                            is_public={g.is_public}
                            link={graph_path(g)}
                            count={count}
                            tags={g.tags}
                            node_count={
                              Enum.count(g.data["nodes"] || [], fn n ->
                                !Map.get(n, "compound", false)
                              end)
                            }
                            is_live={true}
                            generating={MapSet.member?(@generating, g.title)}
                            id={"graph-comp-" <> (g.slug || "t-" <> Integer.to_string(:erlang.phash2(g.title || "")))}
                          />
                          <%= if author_username do %>
                            <div class="mt-1 flex items-center gap-1.5 px-1">
                              <.icon name="hero-user-circle" class="w-3.5 h-3.5 text-white/40" />
                              <.link
                                navigate={~p"/u/#{author_username}"}
                                class="text-xs text-white/50 hover:text-white/80 transition-colors"
                              >
                                by {author_username}
                              </.link>
                            </div>
                          <% end %>
                        </div>
                      <% end %>
                    </div>
                  </div>
                </div>
              </div>
            </section>
            <%!-- Social Media Links --%>
            <section class="w-full pb-8">
              <div class="flex items-center justify-center gap-6">
                <a
                  href="https://github.com/TomBers/dialectic"
                  target="_blank"
                  rel="noopener noreferrer"
                  class="text-white/40 hover:text-white/80 transition-colors"
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
                  class="text-white/40 hover:text-white/80 transition-colors"
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
                  class="text-white/40 hover:text-white/80 transition-colors"
                  aria-label="Instagram"
                >
                  <svg class="h-6 w-6" fill="currentColor" viewBox="0 0 24 24">
                    <path d="M12 2.163c3.204 0 3.584.012 4.85.07 3.252.148 4.771 1.691 4.919 4.919.058 1.265.069 1.645.069 4.849 0 3.205-.012 3.584-.069 4.849-.149 3.225-1.664 4.771-4.919 4.919-1.266.058-1.644.07-4.85.07-3.204 0-3.584-.012-4.849-.07-3.26-.149-4.771-1.699-4.919-4.92-.058-1.265-.07-1.644-.07-4.849 0-3.204.013-3.583.07-4.849.149-3.227 1.664-4.771 4.919-4.919 1.266-.057 1.645-.069 4.849-.069zM12 0C8.741 0 8.333.014 7.053.072 2.695.272.273 2.69.073 7.052.014 8.333 0 8.741 0 12c0 3.259.014 3.668.072 4.948.2 4.358 2.618 6.78 6.98 6.98C8.333 23.986 8.741 24 12 24c3.259 0 3.668-.014 4.948-.072 4.354-.2 6.782-2.618 6.979-6.98.059-1.28.073-1.689.073-4.948 0-3.259-.014-3.667-.072-4.947-.196-4.354-2.617-6.78-6.979-6.98C15.668.014 15.259 0 12 0zm0 5.838a6.162 6.162 0 100 12.324 6.162 6.162 0 000-12.324zM12 16a4 4 0 110-8 4 4 0 010 8zm6.406-11.845a1.44 1.44 0 100 2.881 1.44 1.44 0 000-2.881z" />
                  </svg>
                </a>
                <a
                  href="https://www.linkedin.com/company/rationalgrid-ai//"
                  target="_blank"
                  rel="noopener noreferrer"
                  class="text-white/40 hover:text-white/80 transition-colors"
                  aria-label="LinkedIn"
                >
                  <svg class="h-6 w-6" fill="currentColor" viewBox="0 0 24 24">
                    <path d="M20.447 20.452h-3.554v-5.569c0-1.328-.027-3.037-1.852-3.037-1.853 0-2.136 1.445-2.136 2.939v5.667H9.351V9h3.414v1.561h.046c.477-.9 1.637-1.85 3.37-1.85 3.601 0 4.267 2.37 4.267 5.455v6.286zM5.337 7.433a2.062 2.062 0 01-2.063-2.065 2.064 2.064 0 112.063 2.065zm1.782 13.019H3.555V9h3.564v11.452zM22.225 0H1.771C.792 0 0 .774 0 1.729v20.542C0 23.227.792 24 1.771 24h20.451C23.2 24 24 23.227 24 22.271V1.729C24 .774 23.2 0 22.222 0h.003z" />
                  </svg>
                </a>
              </div>
            </section>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp curated_grid_section(assigns) do
    ~H"""
    <section class="w-full min-w-0">
      <div class="rounded-2xl border border-white/15 bg-white/10 backdrop-blur-md shadow-xl h-full">
        <div class="p-4 sm:p-6">
          <div class="flex items-center gap-3 mb-4">
            <.icon name={@icon} class={"w-6 h-6 " <> @icon_class} />
            <h2 class="text-lg sm:text-2xl font-semibold tracking-tight text-white">
              {@title}
            </h2>
          </div>
          <p class="text-sm text-white/60 mb-5">
            {@description}
          </p>
          <div class="space-y-4 sm:space-y-6">
            <%= for item <- @items do %>
              <div class="relative">
                <DialecticWeb.PageHtml.GraphComp.render
                  title={item.graph.title}
                  is_public={item.graph.is_public}
                  link={graph_path(item.graph)}
                  count={0}
                  tags={item.graph.tags}
                  node_count={
                    Enum.count(item.graph.data["nodes"] || [], fn n ->
                      !Map.get(n, "compound", false)
                    end)
                  }
                  is_live={false}
                  generating={false}
                  id={@id_prefix <> "-" <> (item.graph.slug || "t-" <> Integer.to_string(:erlang.phash2(item.graph.title || "")))}
                />
                <%= if item.author_name do %>
                  <div class="mt-1 flex items-center gap-1.5 px-1">
                    <.icon name="hero-user-circle" class="w-3.5 h-3.5 text-white/40" />
                    <.link
                      navigate={~p"/u/#{item.author_name}"}
                      class="text-xs text-white/50 hover:text-white/80 transition-colors"
                    >
                      {if @author_label != "", do: @author_label <> " ", else: ""}{item.author_name}
                    </.link>
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </section>
    """
  end

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
