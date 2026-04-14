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
       featured_grids: [],
       quick_tags: []
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
    quick_tags = Enum.take(popular_tags, 6)

    {:noreply,
     assign(socket,
       search_term: search_term,
       active_tag: tag,
       active_category: category,
       graphs: graphs,
       popular_tags: popular_tags,
       curated_grids: curated_grids,
       featured_grids: featured_grids,
       quick_tags: quick_tags,
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
        
    <!-- Static decorative background -->
        <div class="absolute inset-0 z-0">
          <div class="pointer-events-none absolute -top-32 -right-24 h-80 w-80 rounded-full bg-sky-100/50 blur-3xl">
          </div>
          <div class="pointer-events-none absolute -top-20 -left-24 h-72 w-72 rounded-full bg-slate-300/35 blur-3xl">
          </div>
        </div>
        
    <!-- Make the hero content scroll within the viewport naturally -->
        <div class="relative z-10 pb-4 sm:pb-5">
          <section class="w-full" id="start-here">
            <div class="w-full bg-gradient-to-br from-[#3a0ca3] to-[#4361ee] px-4 py-3.5 text-white shadow-xl sm:px-6 sm:py-4">
              <div class="mx-auto flex w-full max-w-6xl flex-col items-center gap-1.5 text-center sm:gap-2">
                <p class="text-xs font-medium uppercase tracking-[0.2em] text-white/75 sm:text-sm">
                  Explore -> Recall -> Share
                </p>
                <h1 class="flex items-center justify-center gap-2.5 text-3xl font-extrabold tracking-tight text-white sm:text-4xl">
                  <img
                    src={~p"/images/favicon.webp"}
                    alt=""
                    aria-hidden="true"
                    class="h-9 w-9 rounded-xl shadow-lg sm:h-11 sm:w-11"
                  />
                  <span>RationalGrid</span>
                </h1>
                <div class="mx-auto max-w-2xl space-y-1 sm:space-y-1.5">
                  <p class="text-base font-semibold leading-snug text-white sm:text-xl">
                    Explore ideas, structure arguments and build understanding with AI-powered visual maps.
                  </p>
                  <p class="text-sm leading-relaxed text-white/90">
                    Start with a question and expand into connected concepts you can revisit, recall and share.
                  </p>
                </div>
              </div>
            </div>
          </section>

          <div class="mx-auto max-w-6xl px-4 pt-2 sm:px-6 sm:pt-3">
            <div class="flex flex-col items-stretch gap-2.5 sm:gap-3">
              <section class="w-full">
                <div class="w-full">
                  <div class="flex flex-col items-center gap-2 sm:gap-2.5">
                    <div class="relative mb-2.5 w-full rounded-2xl border-2 border-indigo-300 bg-gradient-to-br from-white via-indigo-50/80 to-sky-50/70 p-2 shadow-[0_16px_38px_rgba(79,70,229,0.30)] ring-2 ring-indigo-200/70 sm:mb-3 sm:p-2.5">
                      <.live_component
                        module={DialecticWeb.NewIdeaFormComp}
                        id="new-idea-form"
                        form={@form}
                      />
                    </div>

                    <div class="grid w-full grid-cols-1 gap-1.5 px-1 text-sm font-semibold sm:grid-cols-2 sm:px-0">
                      <.link
                        navigate={~p"/inspiration"}
                        class={[
                          "inline-flex items-center justify-center gap-2 rounded-xl px-4 py-2",
                          "border border-slate-300 bg-white text-slate-800 shadow-sm",
                          "hover:bg-slate-50 hover:shadow-md transition",
                          "focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-slate-900"
                        ]}
                      >
                        <.icon name="hero-sparkles" class="w-5 h-5" /> Get inspiration
                      </.link>
                      <a
                        href="#explore"
                        class="inline-flex items-center justify-center gap-2 rounded-xl border border-slate-300 bg-white px-4 py-2 text-slate-800 shadow-sm hover:bg-slate-50 hover:shadow-md transition focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-slate-900"
                      >
                        <.icon name="hero-magnifying-glass" class="w-5 h-5" /> Browse ideas
                      </a>
                    </div>

                    <div class="w-full px-1 text-center">
                      <a
                        href="/intro/how#interface-highlight"
                        class="inline-flex items-center gap-1 text-sm font-medium text-slate-600 transition hover:text-indigo-700"
                      >
                        <.icon name="hero-academic-cap" class="h-4 w-4" />
                        How it works: explore, then recall
                      </a>
                    </div>
                  </div>
                </div>
              </section>

              <%!-- Curated & Featured Grids – 2-column on desktop --%>
              <%= if @curated_grids != [] or @featured_grids != [] do %>
                <section
                  class="w-full rounded-3xl bg-slate-50/90 p-2.5 ring-1 ring-slate-200 sm:p-3"
                  id="curated"
                >
                  <div class="grid w-full grid-cols-1 gap-2.5 sm:grid-cols-2">
                    <%= if @curated_grids != [] do %>
                      <.curated_grid_section
                        items={@curated_grids}
                        icon="hero-star"
                        icon_class="text-amber-500"
                        title="Curated Grids"
                        description="Hand-picked grids showcasing great thinking and exploration."
                        id_prefix="curated"
                      />
                    <% end %>
                    <%= if @featured_grids != [] do %>
                      <.curated_grid_section
                        items={@featured_grids}
                        icon="hero-users"
                        icon_class="text-indigo-500"
                        title="Featured by Partners"
                        description="Grids curated by our invited partners and thought leaders."
                        id_prefix="featured"
                      />
                    <% end %>
                  </div>
                </section>
              <% end %>

              <section class="w-full rounded-3xl bg-slate-50/90 p-2.5 ring-1 ring-slate-200 sm:p-3">
                <div class="rounded-2xl bg-white px-3 py-2.5 shadow-sm ring-1 ring-slate-200 sm:px-4">
                  <div class="flex flex-col gap-2 text-sm text-slate-700 sm:flex-row sm:items-center sm:justify-between">
                    <p>
                      Explore a topic by expanding connections, then star and revisit key nodes to support recall.
                    </p>
                    <div class="flex items-center gap-3">
                      <a
                        href="/intro/how#interface-highlight"
                        class="inline-flex items-center gap-1 font-semibold text-indigo-700 hover:text-indigo-800"
                      >
                        <.icon name="hero-book-open" class="h-4 w-4" /> Guide
                      </a>
                      <.link
                        navigate={~p"/about"}
                        class="inline-flex items-center gap-1 font-semibold text-slate-700 hover:text-slate-900"
                      >
                        <.icon name="hero-information-circle" class="h-4 w-4" /> Why this exists
                      </.link>
                    </div>
                  </div>
                </div>
              </section>
              
    <!-- Below: All ideas (full-width on desktop, uses available space) -->
              <section
                class="w-full rounded-3xl bg-white/90 p-2.5 ring-1 ring-slate-200 sm:p-3"
                id="explore"
              >
                <div class="rounded-2xl bg-white shadow-sm ring-1 ring-slate-200">
                  <div class="p-2 sm:p-2.5">
                    <div class="flex flex-col gap-2 sm:gap-3 sm:flex-row sm:items-center sm:justify-between">
                      <h2 class="text-lg sm:text-2xl font-semibold tracking-tight text-slate-900">
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

                      <div class="w-full sm:w-72">
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
                            class="w-full rounded-l-md border border-slate-300 bg-white px-4 py-2.5 text-base text-slate-900 placeholder:text-slate-500 focus:outline-none focus:ring-2 focus:ring-slate-300 sm:py-2"
                            autocomplete="off"
                          />
                          <%= if @search_term && @search_term != "" do %>
                            <button
                              type="button"
                              phx-click="search"
                              phx-value-search=""
                              class="absolute right-12 top-0 bottom-0 flex items-center pr-3 text-slate-500 transition-colors hover:text-slate-700"
                            >
                              <.icon name="hero-x-mark" class="h-5 w-5" />
                            </button>
                          <% end %>
                          <button
                            type="button"
                            class="rounded-r-md border border-l-0 border-slate-300 bg-slate-100 px-4 py-2 text-slate-700 transition hover:bg-slate-200"
                          >
                            <.icon name="hero-magnifying-glass" class="h-5 w-5" />
                          </button>
                        </form>
                      </div>
                    </div>

                    <div class="mt-1.5 space-y-1.5 sm:mt-2 sm:space-y-2">
                      <div class="flex flex-wrap gap-1.5 sm:gap-2">
                        <.link
                          patch={~p"/"}
                          class={[
                            "px-4 py-2 sm:px-3 sm:py-1.5 rounded-full text-sm font-medium transition-colors",
                            (!@active_category && !@active_tag && @search_term == "" &&
                               "bg-slate-900 text-white") ||
                              "bg-slate-100 text-slate-700 hover:bg-slate-200 border border-slate-200"
                          ]}
                        >
                          All
                        </.link>
                        <.link
                          patch={~p"/?category=deep_dives"}
                          class={[
                            "px-4 py-2 sm:px-3 sm:py-1.5 rounded-full text-sm font-medium transition-colors",
                            (@active_category == "deep_dives" && "bg-slate-900 text-white") ||
                              "bg-slate-100 text-slate-700 hover:bg-slate-200 border border-slate-200"
                          ]}
                        >
                          Deep Dives
                        </.link>
                        <.link
                          patch={~p"/?category=seedlings"}
                          class={[
                            "px-4 py-2 sm:px-3 sm:py-1.5 rounded-full text-sm font-medium transition-colors",
                            (@active_category == "seedlings" && "bg-slate-900 text-white") ||
                              "bg-slate-100 text-slate-700 hover:bg-slate-200 border border-slate-200"
                          ]}
                        >
                          Seedlings
                        </.link>
                      </div>

                      <%= if @popular_tags != [] do %>
                        <div class="flex flex-col sm:flex-row sm:flex-wrap items-start sm:items-center gap-2">
                          <span class="text-sm text-slate-600 sm:mr-2 flex-shrink-0">
                            Popular topics:
                          </span>
                          <div class="flex overflow-x-auto scrollbar-hide sm:flex-wrap gap-2 w-full sm:w-auto pb-1 sm:pb-0 -mb-1 sm:mb-0">
                            <%= for {tag, count} <- @popular_tags do %>
                              <.link
                                patch={~p"/?tag=#{tag}"}
                                class={[
                                  "text-xs font-medium px-3 py-1.5 sm:px-2.5 sm:py-0.5 rounded border transition-colors whitespace-nowrap flex-shrink-0",
                                  (@active_tag == tag && "bg-slate-900 text-white border-slate-900") ||
                                    "bg-slate-100 text-slate-700 border-slate-200 hover:border-slate-300 hover:bg-slate-200"
                                ]}
                              >
                                #{tag} <span class="ml-0.5 text-slate-500">({count})</span>
                              </.link>
                            <% end %>
                          </div>
                        </div>
                      <% end %>
                    </div>
                  </div>

                  <div class="border-t border-slate-200">
                    <div class="overflow-x-auto p-3 sm:p-3.5">
                      <table class="min-w-full border-separate border-spacing-0 text-left text-sm">
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
                                <.link
                                  navigate={graph_path(g)}
                                  class="line-clamp-2 font-semibold text-slate-900 hover:text-indigo-700"
                                >
                                  {g.title}
                                </.link>
                                <%= if is_binary(author_username) and author_username != "" do %>
                                  <.link
                                    navigate={~p"/u/#{author_username}"}
                                    class="mt-1 inline-flex text-xs text-slate-600 hover:text-indigo-700"
                                  >
                                    by @{author_username}
                                  </.link>
                                <% else %>
                                  <p class="mt-1 text-xs text-slate-500">by -</p>
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
              <section class="w-full pb-3">
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

  defp curated_grid_section(assigns) do
    ~H"""
    <section class="w-full min-w-0">
      <div class="h-full rounded-2xl bg-white shadow-sm ring-1 ring-slate-200">
        <div class="p-2.5 sm:p-3">
          <div class="mb-2 flex items-center gap-2.5">
            <.icon name={@icon} class={"w-6 h-6 " <> @icon_class} />
            <h2 class="text-lg font-bold tracking-tight text-slate-900 sm:text-2xl">
              {@title}
            </h2>
          </div>
          <p class="mb-2 text-sm text-slate-600">
            {@description}
          </p>
          <div class="space-y-2 sm:space-y-3">
            <%= for item <- @items do %>
              <div class="relative">
                <DialecticWeb.PageHtml.GraphComp.render
                  title={item.graph.title}
                  is_public={item.graph.is_public}
                  link={graph_path(item.graph)}
                  count={0}
                  tags={item.graph.tags}
                  author_name={item.author_name}
                  author_label="by"
                  variant={:light}
                  compact={true}
                  node_count={
                    Enum.count(item.graph.data["nodes"] || [], fn n ->
                      !Map.get(n, "compound", false)
                    end)
                  }
                  is_live={false}
                  generating={false}
                  id={@id_prefix <> "-" <> (item.graph.slug || "t-" <> Integer.to_string(:erlang.phash2(item.graph.title || "")))}
                />
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
