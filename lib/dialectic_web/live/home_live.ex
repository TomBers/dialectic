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
       graph_id: nil
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

    {:noreply,
     assign(socket,
       search_term: search_term,
       active_tag: tag,
       active_category: category,
       graphs: graphs,
       popular_tags: popular_tags,
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

    if title == "untitled-idea" do
      {:noreply, put_flash(socket, :error, "Please enter a question or topic.")}
    else
      existing_graph = Graphs.get_graph_by_title(title)

      if existing_graph do
        {:noreply, redirect(socket, to: graph_path(existing_graph))}
      else
        parent_pid = self()
        assigns = socket.assigns

        socket =
          socket
          |> assign(:loading_graph, %{title: title, status: "Initializing...", steps: []})
          |> start_async(:create_graph_flow, fn ->
            create_graph_task(title, answer, assigns, parent_pid)
          end)

        {:noreply, socket}
      end
    end
  end

  @impl true
  def handle_event("generate_tags", %{"title" => title}, socket) do
    case Graphs.get_graph_by_title(title) do
      nil ->
        {:noreply, put_flash(socket, :error, "Graph not found")}

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
        {:noreply, put_flash(socket, :error, "Graph not found after creation")}

      graph ->
        {:noreply, redirect(socket, to: graph_path(graph))}
    end
  end

  def handle_async(:create_graph_flow, {:ok, _}, socket) do
    {:noreply,
     put_flash(socket, :error, "Failed to create mind map") |> assign(:loading_graph, nil)}
  end

  def handle_async(:create_graph_flow, {:exit, reason}, socket) do
    # Log the crash reason if needed
    Logger.error("Mind map creation crashed: #{inspect(reason)}")

    {:noreply,
     put_flash(socket, :error, "Mind map creation failed. Please try again.")
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

  defp create_graph_task(title, answer, assigns, parent_pid) do
    mode_str = assigns[:prompt_mode] || "university"

    mode =
      case mode_str do
        "expert" -> :expert
        "high_school" -> :high_school
        "simple" -> :simple
        _ -> :university
      end

    user_identity = UserUtils.current_identity(assigns)
    current_user = assigns[:current_user]

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
        <div class="relative z-10 mx-auto max-w-7xl px-6 pt-14 pb-10 min-h-[calc(100vh-4rem)]">
          <div class="flex flex-col gap-10 items-stretch">
            <!-- Top: Create new idea (primary action, centered stack with breathing room) -->
            <section class="w-full">
              <div class="mx-auto w-full max-w-3xl">
                <div class="flex flex-col items-center text-center gap-7">
                  <div class="space-y-4">
                    <h1 class="text-4xl font-bold tracking-tight text-white sm:text-5xl">
                      MuDG
                    </h1>
                    <p class="text-xl font-medium text-indigo-100">
                      A shared AI-powered whiteboard; explore ideas deeply, structure thinking, and sharpen arguments.
                    </p>
                  </div>

                  <div class="w-full bg-white/10 backdrop-blur-md rounded-2xl shadow-xl border border-white/15 p-6">
                    <.live_component
                      module={DialecticWeb.NewIdeaFormComp}
                      id="new-idea-form"
                      form={@form}
                    />
                  </div>

                  <div class="flex flex-col sm:flex-row items-stretch sm:items-center justify-center gap-3 text-sm font-semibold w-full">
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

                  <div class="h-6 sm:h-10" />
                </div>
              </div>
            </section>
            
    <!-- Below: Existing ideas (full-width on desktop, uses available space) -->
            <section class="w-full" id="explore">
              <div class="rounded-2xl border border-white/15 bg-white/10 backdrop-blur-md shadow-xl">
                <div class="p-5 sm:p-6">
                  <div class="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
                    <h2 class="text-xl sm:text-2xl font-semibold tracking-tight text-white">
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
                          Existing Mind Maps
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
                          class="w-full px-4 py-2 rounded-l-md border border-white/15 bg-white/10 text-white placeholder:text-white/60 focus:outline-none focus:ring-2 focus:ring-white/30"
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

                  <div class="mt-5 space-y-4">
                    <div class="flex flex-wrap gap-2">
                      <.link
                        patch={~p"/"}
                        class={[
                          "px-3 py-1.5 rounded-full text-sm font-medium transition-colors",
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
                          "px-3 py-1.5 rounded-full text-sm font-medium transition-colors",
                          (@active_category == "deep_dives" && "bg-white text-[#3a0ca3]") ||
                            "bg-white/10 text-white hover:bg-white/15 border border-white/10"
                        ]}
                      >
                        Deep Dives
                      </.link>
                      <.link
                        patch={~p"/?category=seedlings"}
                        class={[
                          "px-3 py-1.5 rounded-full text-sm font-medium transition-colors",
                          (@active_category == "seedlings" && "bg-white text-[#3a0ca3]") ||
                            "bg-white/10 text-white hover:bg-white/15 border border-white/10"
                        ]}
                      >
                        Seedlings
                      </.link>
                    </div>

                    <%= if @popular_tags != [] do %>
                      <div class="flex flex-wrap items-center gap-2">
                        <span class="text-sm text-white/70 mr-2">Popular topics:</span>
                        <%= for {tag, count} <- @popular_tags do %>
                          <.link
                            patch={~p"/?tag=#{tag}"}
                            class={[
                              "text-xs font-medium px-2.5 py-0.5 rounded border transition-colors",
                              (@active_tag == tag && "bg-white text-[#3a0ca3] border-white") ||
                                "bg-white/10 text-white border-white/15 hover:border-white/30 hover:bg-white/15"
                            ]}
                          >
                            #{tag} <span class="text-white/60 ml-0.5">(#{count})</span>
                          </.link>
                        <% end %>
                      </div>
                    <% end %>
                  </div>
                </div>

                <div class="border-t border-white/10">
                  <div class="p-5 sm:p-6">
                    <div class="columns-1 sm:columns-2 lg:columns-3 gap-6 space-y-6">
                      <%= for {g, count} <- @graphs do %>
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
                            id={"graph-comp-#{g.title}"}
                          />
                        </div>
                      <% end %>
                    </div>
                  </div>
                </div>
              </div>
            </section>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp fetch_graphs(search_term, tag, category, limit) do
    cond do
      is_binary(tag) && tag != "" ->
        Dialectic.DbActions.Graphs.list_graphs_by_tag(tag, limit)
        |> Enum.map(&{&1, 0})

      category == "deep_dives" ->
        Dialectic.DbActions.Graphs.list_deep_dives(limit)
        |> Enum.map(&{&1, 0})

      category == "seedlings" ->
        Dialectic.DbActions.Graphs.list_seedlings(limit)
        |> Enum.map(&{&1, 0})

      true ->
        Dialectic.DbActions.Graphs.all_graphs_with_notes(search_term)
        |> Enum.take(limit)
    end
  end

  defp page_title(search, tag, category) do
    cond do
      is_binary(tag) and tag != "" -> "Tagged: #{tag}"
      category == "deep_dives" -> "Deep Dives"
      category == "seedlings" -> "Seedlings"
      is_binary(search) and search != "" -> "Search: #{search}"
      true -> "MuDG"
    end
  end
end
