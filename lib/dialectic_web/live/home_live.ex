defmodule DialecticWeb.HomeLive do
  use DialecticWeb, :live_view
  alias Dialectic.DbActions.Graphs

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       search_term: "",
       active_tag: nil,
       active_category: nil,
       graphs: [],
       popular_tags: [],
       limit: 20
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
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50 text-gray-800">
      <!-- Hero -->
      <header class="relative overflow-hidden bg-gradient-to-r from-[#3a0ca3] to-[#4361ee] py-12">
        <div class="absolute inset-0 opacity-5 bg-[url('data:image/svg+xml,%3Csvg width=\'60\' height=\'60\' viewBox=\'0 0 60 60\' xmlns=\'http://www.w3.org/2000/svg\'%3E%3Cg fill=\'none\' fill-rule=\'evenodd\'%3E%3Cg fill=\'%23ffffff\' fill-opacity=\'0.2\'%3E%3Cpath d=\'M36 34v-4h-2v4h-4v2h4v4h2v-4h4v-2h-4zm0-30V0h-2v4h-4v2h4v4h2V6h4V4h-4zM6 34v-4H4v4H0v2h4v4h2v-4h4v-2H6zM6 4V0H4v4H0v2h4v4h2V6h4V4H6z\'/%3E%3C/g%3E%3C/g%3E%3C/svg%3E')]">
        </div>
        <div class="relative z-10">
          <div class="mx-auto max-w-7xl px-6 md:grid md:grid-cols-2 md:items-center md:gap-12">
            <div class="text-center md:text-left">
              <h1 class="text-4xl md:text-5xl font-bold tracking-tight text-white">
                Explore ideas collaboratively
              </h1>
              <p class="mt-4 text-lg md:text-xl text-blue-100/90">
                Explore, connect, and learn together.
              </p>
              <div class="mt-6 flex flex-wrap justify-center md:justify-start gap-3">
                <.link
                  navigate={~p"/intro/how"}
                  class="inline-flex items-center rounded-full bg-white text-[#3a0ca3] px-5 py-2.5 font-semibold ring-1 ring-white/20 hover:bg-white/15 transition"
                >
                  Guide
                </.link>
                <.link
                  href="https://tombers.github.io/dialectic/"
                  target="_blank"
                  rel="noopener noreferrer"
                  class="inline-flex items-center rounded-full bg-transparent text-white px-5 py-2.5 font-semibold ring-1 ring-white/30 hover:bg-white/10 transition"
                >
                  Learn more
                </.link>
              </div>
            </div>
            <div class="mt-10 md:mt-0 flex justify-center md:justify-end">
              <img
                src="/images/Landing2.webp"
                alt="Dialectic interface screenshot"
                class="w-full max-w-[560px] ring-1 ring-black/5"
                loading="lazy"
              />
            </div>
          </div>
        </div>
      </header>
      
    <!-- Create conversation -->
      <section id="create-conv" class="mx-auto max-w-7xl px-6">
        <div class="mt-10 rounded-xl bg-white ring-1 ring-gray-200 shadow-sm">
          <div class="p-6 sm:p-8">
            <div class="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
              <div>
                <h2 class="text-2xl font-semibold text-gray-900">Start a new exploration</h2>
                <p class="mt-1 text-gray-600">
                  Create a MuDG to map your ideas clearly with context that stays visible.
                </p>
              </div>
              <.link
                navigate={~p"/start/new/idea"}
                class="inline-flex items-center gap-2 rounded-lg bg-[#4361ee] px-5 py-3 font-semibold text-white shadow-sm hover:bg-[#3a56d9] transition"
              >
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  class="h-5 w-5 -ml-0.5"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                  aria-hidden="true"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M12 6v12m6-6H6"
                  />
                </svg>
                New exploration
              </.link>
            </div>
          </div>
        </div>
      </section>
      
    <!-- Why section -->
      <section class="mx-auto max-w-7xl px-6">
        <div class="mt-12 text-center">
          <h2 class="text-3xl font-bold text-gray-900">Why MuDG?</h2>

          <ul class="mt-6 space-y-4 text-left max-w-3xl mx-auto text-lg text-gray-600 list-disc list-inside">
            <li>
              <span class="font-semibold text-gray-900">See the structure of your thinking</span> –
              Turn messy, linear chat into a visual map of how ideas branch, connect, and evolve, so you can dive deep without losing the bigger picture.
            </li>
            <li>
              <span class="font-semibold text-gray-900">Explore together in real time</span> –
              Invite others into the same MuDG to add questions, examples, and perspectives as you go, turning solitary learning into a shared exploration.
            </li>
            <li>
              <span class="font-semibold text-gray-900">Build on a living knowledge base</span> –
              Reuse existing graphs, follow others’ explorations, and connect your own ideas to what the community is already mapping.
            </li>
          </ul>
        </div>

        <div class="mt-10 grid grid-cols-1 gap-6 md:grid-cols-2">
          <!-- MuDG card -->
          <div class="group relative overflow-hidden rounded-2xl bg-white ring-1 ring-gray-200 shadow-sm transition hover:shadow-md">
            <img
              src="/images/home_graph.webp"
              alt="MuDG graph example"
              class="absolute inset-0 h-full w-full object-cover"
              style="background:white;"
            />
            <div class="relative h-[300px] md:h-[380px]"></div>
            <div class="relative border-t border-gray-100 bg-white p-5">
              <div class="flex items-center justify-between">
                <div>
                  <h3 class="text-xl font-semibold text-gray-900">MuDG</h3>
                  <p class="mt-1 text-gray-600">
                    Clear paths and visible context. Build knowledge with deliberate structure.
                  </p>
                </div>
                <span class="inline-flex items-center rounded-full bg-[#eef2ff] text-[#3a0ca3] px-3 py-1 text-sm font-medium">
                  Structured
                </span>
              </div>
            </div>
          </div>
          
    <!-- ChatGPT card -->
          <div class="group relative overflow-hidden rounded-2xl bg-white ring-1 ring-gray-200 shadow-sm transition hover:shadow-md">
            <img
              src="/images/chatgpt.webp"
              alt="Chat conversation example"
              class="absolute inset-0 h-full w-full object-contain bg-white"
            />
            <div class="relative h-[300px] md:h-[380px]"></div>
            <div class="relative border-t border-gray-100 bg-white p-5">
              <div class="flex items-center justify-between">
                <div>
                  <h3 class="text-xl font-semibold text-gray-900">ChatGPT</h3>
                  <p class="mt-1 text-gray-600">
                    Linear threads require constant looping back to context, slowing deep dives.
                  </p>
                </div>
                <span class="inline-flex items-center rounded-full bg-gray-100 text-gray-700 px-3 py-1 text-sm font-medium">
                  Linear
                </span>
              </div>
            </div>
          </div>
        </div>
      </section>
      
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
                  Explore Ideas
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
                  node_count={length(g.data["nodes"] || [])}
                  id={"graph-comp-#{g.title}"}
                />
              </div>
            <% end %>
          </div>
        </div>
      </section>
      
    <!-- Testimonial -->
      <section class="mx-auto max-w-7xl px-6">
        <div class="mt-16 rounded-xl bg-white ring-1 ring-gray-200 shadow-sm">
          <div class="p-6 sm:p-10">
            <div class="text-center">
              <h2 class="text-2xl font-semibold text-gray-900">What our users say</h2>
            </div>
            <div class="mt-8 flex justify-center">
              <figure class="max-w-3xl">
                <svg
                  class="h-8 w-8 text-[#4361ee] mx-auto opacity-80"
                  viewBox="0 0 24 24"
                  fill="currentColor"
                  aria-hidden="true"
                >
                  <path d="M7.17 6A5.17 5.17 0 0 0 2 11.17V21h8v-9.83A5.17 5.17 0 0 0 4.83 6H7.17zm10 0A5.17 5.17 0 0 0 12 11.17V21h8v-9.83A5.17 5.17 0 0 0 14.83 6h2.34z" />
                </svg>
                <blockquote class="mt-4 text-lg text-gray-700 italic">
                  An amazing free specialised AI tool to explore philosophical ideas around pretty much anything — from academic questions to films to... hamsters! All at one's fingertips, in a matter of seconds, with in-built tools for a sophisticated, yet accessible dialectic. Bravo!
                </blockquote>
                <figcaption class="mt-6 flex items-center justify-center gap-3">
                  <span class="inline-flex h-10 w-10 items-center justify-center rounded-full bg-[#4361ee] text-white font-bold">
                    AK
                  </span>
                  <div class="text-left">
                    <div class="font-semibold text-gray-900">Alexandra Konoplyanik</div>
                    <a
                      href="https://pfalondon.org/"
                      target="_blank"
                      rel="noopener noreferrer"
                      class="text-sm text-[#4361ee] hover:text-[#3a56d9]"
                    >
                      Philosophy for All
                    </a>
                  </div>
                </figcaption>
              </figure>
            </div>
            <div class="mt-4 text-right">
              <a href="#explore" class="text-sm font-medium text-[#4361ee] hover:text-[#3a56d9]">
                Explore all →
              </a>
            </div>
          </div>
        </div>
      </section>
    </div>

    <!-- Footer -->
    <footer class="mt-16 w-full bg-gradient-to-r from-[#3a0ca3] to-[#4361ee]">
      <section class="mx-auto max-w-7xl px-6 py-14 text-center text-white">
        <h2 class="text-3xl md:text-4xl font-semibold tracking-tight">
          Ready to transform your learning?
        </h2>
        <p class="mt-3 text-blue-100/90 max-w-2xl mx-auto">
          Join a growing community of collaborative thinkers.
        </p>
        <div class="mt-6 flex flex-wrap justify-center gap-3">
          <a
            href="/start/new/idea"
            class="inline-flex items-center rounded-full bg-white text-[#3a0ca3] px-5 py-2.5 font-semibold shadow-sm ring-1 ring-white/20 hover:bg-white/90 transition"
          >
            Start exploring
          </a>
          <a
            href="https://x.com/TJCBerman"
            target="_blank"
            class="inline-flex items-center gap-2 rounded-full bg-white/10 text-white px-5 py-2.5 font-semibold ring-1 ring-white/20 hover:bg-white/15 transition"
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="h-5 w-5 -ml-0.5"
              fill="currentColor"
              viewBox="0 0 24 24"
              aria-hidden="true"
            >
              <path d="M18.244 2.25h3.308l-7.227 8.26 8.502 11.24H16.17l-5.214-6.817L4.99 21.75H1.68l7.73-8.835L1.254 2.25H8.08l4.713 6.231zm-1.161 17.52h1.833L7.084 4.126H5.117z" />
            </svg>
            Follow @TJCBerman
          </a>
        </div>
        <div class="mt-10 text-white/70 text-sm">
          &copy; 2025 Dialectic — Multi-user Dialectical Graph (MuDG)
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
      true -> "Dialectic"
    end
  end

  defp gen_link(title) do
    # Simple helper to generate link, matching logic in controller/views
    "/#{URI.encode(title)}"
  end
end
