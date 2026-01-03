defmodule DialecticWeb.HomeLive do
  use DialecticWeb, :live_view
  alias Dialectic.DbActions.Graphs
  alias Dialectic.Graph.GraphActions
  alias Dialectic.Graph.Vertex
  alias Dialectic.Responses.ModeServer
  alias DialecticWeb.Utils.UserUtils

  on_mount {DialecticWeb.UserAuth, :mount_current_user}

  @impl true
  def mount(params, _session, socket) do
    if connected?(socket), do: Phoenix.PubSub.subscribe(Dialectic.PubSub, "graphs")

    user = UserUtils.current_identity(socket.assigns)
    initial_content = params["initial_prompt"]

    changeset =
      GraphActions.create_new_node(user)
      |> Vertex.changeset(if initial_content, do: %{content: initial_content}, else: %{})

    prompt_mode =
      case params do
        %{"mode" => mode} when is_binary(mode) ->
          case String.downcase(mode) do
            "creative" -> "creative"
            _ -> "structured"
          end

        _ ->
          "structured"
      end

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
  def handle_event("reply-and-answer", %{"vertex" => %{"content" => answer}}, socket) do
    title = sanitize_graph_title(answer)

    case Graphs.create_new_graph(title, socket.assigns[:current_user]) do
      {:ok, _graph} ->
        mode_str = socket.assigns[:prompt_mode] || "structured"
        mode = if mode_str == "creative", do: :creative, else: :structured
        ModeServer.set_mode(title, mode)

        GraphManager.get_graph(title)
        node = GraphManager.find_node_by_id(title, "1")

        user_identity = UserUtils.current_identity(socket.assigns)
        topic = "graph_update:#{title}"

        GraphActions.ask_and_answer_origin(
          {title, node, user_identity, topic},
          answer
        )

        {:noreply, socket |> redirect(to: ~p"/#{title}")}

      {:error, _changeset} ->
        case Graphs.get_graph_by_title(title) do
          nil ->
            {:noreply, socket |> put_flash(:error, "Error creating graph")}

          _graph ->
            {:noreply, socket |> redirect(to: ~p"/#{title}")}
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

  defp sanitize_graph_title(title) do
    sanitized =
      title
      |> String.slice(0, 140)
      |> String.trim()
      |> String.replace("/", "-")

    if sanitized == "", do: "untitled-idea", else: sanitized
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50 text-gray-800">
      <div class="relative min-h-[calc(100vh-4rem)] flex flex-col items-center justify-center overflow-hidden">
        <!-- Background Video with Overlay -->
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

        <div class="relative z-10 w-full max-w-2xl px-6 flex flex-col items-center space-y-8">
          <div class="text-center space-y-4">
            <h1 class="text-4xl font-bold tracking-tight text-white sm:text-5xl">
              Start a new thought process
            </h1>
            <p class="text-lg text-indigo-100">
              Ask a question or state a premise to begin exploring a new dialectic map.
            </p>
          </div>

          <div class="w-full bg-white/80 backdrop-blur-md rounded-2xl shadow-xl border border-gray-200 p-6">
            <.live_component module={DialecticWeb.NewIdeaFormComp} id="new-idea-form" form={@form} />
          </div>

          <div class="flex items-center gap-8 text-sm font-medium">
            <.link
              navigate={~p"/inspiration"}
              class="flex items-center gap-2 text-indigo-100 hover:text-white transition-colors group"
            >
              <span class="p-1.5 rounded-lg bg-indigo-500/30 group-hover:bg-indigo-500/50 transition-colors">
                <.icon name="hero-sparkles" class="w-4 h-4" />
              </span>
              Inspire me
            </.link>
            <.link
              navigate={~p"/intro/how"}
              class="flex items-center gap-2 text-indigo-100 hover:text-white transition-colors group"
            >
              <span class="p-1.5 rounded-lg bg-indigo-500/30 group-hover:bg-indigo-500/50 transition-colors">
                <.icon name="hero-book-open" class="w-4 h-4" />
              </span>
              Read the guide
            </.link>
          </div>
        </div>
      </div>
      
    <!-- Explore Ideas (Masonry Grid) -->
      <section class="mx-auto max-w-7xl px-6" id="explore">
        <div class="mt-16">
          <div class="flex justify-between items-center mb-6">
            <h2 class="text-2xl font-bold text-gray-700">
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
                  Existing Ideas
              <% end %>
            </h2>
            <div class="w-1/3">
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
                  class="w-full px-4 py-2 rounded-l-md border border-gray-300 focus:outline-none focus:ring-2 focus:ring-blue-500"
                  autocomplete="off"
                />
                <%= if @search_term && @search_term != "" do %>
                  <button
                    type="button"
                    phx-click="search"
                    phx-value-search=""
                    class="absolute right-12 top-0 bottom-0 flex items-center pr-3 text-gray-500 hover:text-gray-700"
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
                  class="bg-blue-500 text-white px-4 py-2 rounded-r-md hover:bg-blue-600 transition"
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

          <div class="mb-8 space-y-4">
            <div class="flex flex-wrap gap-2">
              <.link
                patch={~p"/"}
                class={[
                  "px-3 py-1.5 rounded-full text-sm font-medium transition-colors",
                  (!@active_category && !@active_tag && @search_term == "" && "bg-gray-900 text-white") ||
                    "bg-gray-100 text-gray-700 hover:bg-gray-200"
                ]}
              >
                All
              </.link>
              <.link
                patch={~p"/?category=deep_dives"}
                class={[
                  "px-3 py-1.5 rounded-full text-sm font-medium transition-colors",
                  (@active_category == "deep_dives" && "bg-indigo-600 text-white") ||
                    "bg-indigo-50 text-indigo-700 hover:bg-indigo-100"
                ]}
              >
                Deep Dives
              </.link>
              <.link
                patch={~p"/?category=seedlings"}
                class={[
                  "px-3 py-1.5 rounded-full text-sm font-medium transition-colors",
                  (@active_category == "seedlings" && "bg-green-600 text-white") ||
                    "bg-green-50 text-green-700 hover:bg-green-100"
                ]}
              >
                Seedlings
              </.link>
            </div>

            <%= if @popular_tags != [] do %>
              <div class="flex flex-wrap items-center gap-2">
                <span class="text-sm text-gray-500 mr-2">Popular topics:</span>
                <%= for {tag, count} <- @popular_tags do %>
                  <.link
                    patch={~p"/?tag=#{tag}"}
                    class={[
                      "text-xs font-medium px-2.5 py-0.5 rounded border transition-colors",
                      (@active_tag == tag && "bg-blue-100 text-blue-800 border-blue-200") ||
                        "bg-white text-gray-600 border-gray-200 hover:border-gray-300"
                    ]}
                  >
                    #{tag} <span class="text-gray-400 ml-0.5">(#{count})</span>
                  </.link>
                <% end %>
              </div>
            <% end %>
          </div>

          <div class="columns-1 sm:columns-2 lg:columns-3 gap-6 space-y-6 pb-12">
            <%= for {g, count} <- @graphs do %>
              <div class="break-inside-avoid">
                <DialecticWeb.PageHtml.GraphComp.render
                  title={g.title}
                  is_public={g.is_public}
                  link={gen_link(g.title)}
                  count={count}
                  tags={g.tags}
                  node_count={
                    Enum.count(g.data["nodes"] || [], fn n -> !Map.get(n, "compound", false) end)
                  }
                  is_live={true}
                  generating={MapSet.member?(@generating, g.title)}
                  id={"graph-comp-#{g.title}"}
                />
              </div>
            <% end %>
          </div>
        </div>
      </section>
    </div>

    <!-- Footer -->
    <footer class="mt-16 relative left-1/2 right-1/2 -ml-[50vw] -mr-[50vw] w-screen bg-gradient-to-r from-[#3a0ca3] to-[#4361ee]">
      <section class="mx-auto max-w-7xl px-6 py-8 text-center text-white">
        <div class="flex flex-col md:flex-row items-center justify-center gap-6">
          <h2 class="text-xl font-semibold tracking-tight">
            Ready to transform your learning?
          </h2>
          <div class="flex flex-wrap justify-center gap-3">
            <.link
              navigate={~p"/"}
              class="inline-flex items-center rounded-full bg-white text-[#3a0ca3] px-4 py-1.5 text-sm font-semibold shadow-sm ring-1 ring-white/20 hover:bg-white/90 transition"
            >
              Start exploring
            </.link>
            <a
              href="https://x.com/TJCBerman"
              target="_blank"
              class="inline-flex items-center gap-2 rounded-full bg-white/10 text-white px-4 py-1.5 text-sm font-semibold ring-1 ring-white/20 hover:bg-white/15 transition"
            >
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="h-4 w-4"
                fill="currentColor"
                viewBox="0 0 24 24"
                aria-hidden="true"
              >
                <path d="M18.244 2.25h3.308l-7.227 8.26 8.502 11.24H16.17l-5.214-6.817L4.99 21.75H1.68l7.73-8.835L1.254 2.25H8.08l4.713 6.231zm-1.161 17.52h1.833L7.084 4.126H5.117z" />
              </svg>
              Follow
            </a>
          </div>
        </div>
      </section>
    </footer>
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

  defp gen_link(title) do
    # Simple helper to generate link, matching logic in controller/views
    "/#{URI.encode(title)}"
  end
end
