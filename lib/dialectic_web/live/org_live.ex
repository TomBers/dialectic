defmodule DialecticWeb.OrgLive do
  use DialecticWeb, :live_view

  alias Dialectic.DbActions.Graphs
  alias Dialectic.Graph.GraphActions
  alias Dialectic.Graph.Vertex
  alias DialecticWeb.Utils.UserUtils
  require Logger

  on_mount {DialecticWeb.UserAuth, :mount_current_user}

  @orgs %{
    "acme-research" => %{
      slug: "acme-research",
      name: "Acme Research Institute",
      short_name: "Acme Research",
      description:
        "Pushing the boundaries of knowledge through collaborative AI-powered research exploration.",
      long_description:
        "Acme Research Institute brings together scientists, engineers, and thinkers to explore complex questions at the frontier of human understanding. Our MuDG spaces let teams map out research questions, build argument trees, and discover unexpected connections across disciplines.",
      icon: "hero-beaker",
      accent: "violet",
      accent_from: "from-violet-600",
      accent_to: "to-purple-700",
      accent_ring: "ring-violet-400/30",
      accent_bg: "bg-violet-500/15",
      accent_text: "text-violet-200",
      accent_badge: "bg-violet-500/20 text-violet-100 ring-violet-300/30",
      tags: ["science", "research", "philosophy", "technology"],
      stats: %{members: 142, graphs: 87, explorations: "2.4k"}
    },
    "bright-futures" => %{
      slug: "bright-futures",
      name: "Bright Futures Academy",
      short_name: "Bright Futures",
      description:
        "Empowering students to think critically and explore ideas through structured debate and inquiry.",
      long_description:
        "Bright Futures Academy uses MuDG as a learning tool to help students develop critical thinking skills. By mapping arguments visually and exploring multiple perspectives, learners build deeper understanding of complex topics — from history to ethics to science.",
      icon: "hero-academic-cap",
      accent: "amber",
      accent_from: "from-amber-500",
      accent_to: "to-orange-600",
      accent_ring: "ring-amber-400/30",
      accent_bg: "bg-amber-500/15",
      accent_text: "text-amber-200",
      accent_badge: "bg-amber-500/20 text-amber-100 ring-amber-300/30",
      tags: ["education", "history", "ethics", "debate"],
      stats: %{members: 318, graphs: 215, explorations: "5.1k"}
    },
    "green-earth" => %{
      slug: "green-earth",
      name: "Green Earth Collective",
      short_name: "Green Earth",
      description:
        "Mapping the complex web of environmental challenges and collaborating on sustainable solutions.",
      long_description:
        "The Green Earth Collective uses MuDG to untangle the interconnected challenges of climate change, biodiversity loss, and sustainable development. Our community maps out policy arguments, explores trade-offs, and builds evidence-based cases for environmental action.",
      icon: "hero-globe-americas",
      accent: "emerald",
      accent_from: "from-emerald-500",
      accent_to: "to-teal-600",
      accent_ring: "ring-emerald-400/30",
      accent_bg: "bg-emerald-500/15",
      accent_text: "text-emerald-200",
      accent_badge: "bg-emerald-500/20 text-emerald-100 ring-emerald-300/30",
      tags: ["climate", "environment", "sustainability", "policy"],
      stats: %{members: 97, graphs: 64, explorations: "1.8k"}
    }
  }

  def list_orgs, do: Map.values(@orgs)

  def get_org(slug), do: Map.get(@orgs, slug)

  @impl true
  def mount(_params, _session, socket) do
    socket = assign(socket, :loading_graph, nil)
    user = UserUtils.current_identity(socket.assigns)

    changeset =
      GraphActions.create_new_node(user)
      |> Vertex.changeset(%{})

    {:ok,
     assign(socket,
       user: user,
       form: to_form(changeset),
       prompt_mode: "university",
       graphs: [],
       org: nil
     )}
  end

  @impl true
  def handle_params(%{"org_slug" => org_slug}, _url, socket) do
    case get_org(org_slug) do
      nil ->
        {:noreply,
         socket
         |> put_flash(:error, "Organisation not found.")
         |> push_navigate(to: ~p"/")}

      org ->
        graphs = fetch_org_graphs(org.tags, 12)

        {:noreply,
         assign(socket,
           org: org,
           graphs: graphs,
           page_title: org.name
         )}
    end
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
  def handle_async(:create_graph_flow, {:ok, {:ok, title}}, socket) do
    case Graphs.get_graph_by_title(title) do
      nil ->
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

  defp fetch_org_graphs(tags, limit) do
    # Fetch public graphs that match any of the org's tags
    all_tagged =
      tags
      |> Enum.flat_map(fn tag ->
        Graphs.list_graphs_by_tag(tag, limit)
      end)
      |> Enum.uniq_by(& &1.title)
      |> Enum.take(limit)

    # If not enough tagged graphs, backfill with recent public graphs
    if length(all_tagged) < 3 do
      recent =
        Graphs.all_graphs_with_notes("")
        |> Enum.take(limit)
        |> Enum.map(fn {g, _count} -> g end)

      (all_tagged ++ recent)
      |> Enum.uniq_by(& &1.title)
      |> Enum.take(limit)
    else
      all_tagged
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-[calc(100vh-4rem)] w-screen bg-slate-950 text-white">
      <div class="relative min-h-[calc(100vh-4rem)] w-screen overflow-hidden">
        <%!-- Loading overlay --%>
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

        <%!-- Background gradient --%>
        <div class={[
          "absolute inset-0 z-0 bg-gradient-to-br",
          @org.accent_from,
          @org.accent_to
        ]}>
          <div class="absolute inset-0 bg-slate-950/40"></div>
        </div>

        <%!-- Main content --%>
        <div class="relative z-10 mx-auto max-w-7xl px-6 pt-10 pb-16">
          <%!-- Back to home --%>
          <div class="mb-8">
            <.link
              navigate={~p"/"}
              class="inline-flex items-center gap-2 text-sm text-white/70 hover:text-white transition-colors"
            >
              <.icon name="hero-arrow-left" class="w-4 h-4" /> Back to MuDG
            </.link>
          </div>

          <%!-- Org hero --%>
          <section class="mb-12">
            <div class="flex flex-col sm:flex-row items-start gap-6">
              <%!-- Org icon --%>
              <div class={[
                "flex-shrink-0 w-20 h-20 rounded-2xl flex items-center justify-center border",
                @org.accent_bg,
                @org.accent_ring
              ]}>
                <.icon name={@org.icon} class="w-10 h-10 text-white" />
              </div>

              <div class="flex-1 space-y-3">
                <div class="flex items-center gap-3 flex-wrap">
                  <h1 class="text-3xl sm:text-4xl font-bold tracking-tight text-white">
                    {@org.name}
                  </h1>
                  <span class={[
                    "inline-flex items-center rounded-full px-3 py-1 text-xs font-bold ring-1 ring-inset",
                    @org.accent_badge
                  ]}>
                    <.icon name="hero-star" class="w-3 h-3 mr-1" /> Special MuDG
                  </span>
                </div>
                <p class="text-lg text-white/80 max-w-2xl">{@org.description}</p>

                <%!-- Stats row --%>
                <div class="flex flex-wrap gap-6 pt-2">
                  <div class="flex items-center gap-2">
                    <.icon name="hero-users" class="w-5 h-5 text-white/50" />
                    <span class="text-sm">
                      <span class="font-bold text-white">{@org.stats.members}</span>
                      <span class="text-white/60">members</span>
                    </span>
                  </div>
                  <div class="flex items-center gap-2">
                    <.icon name="hero-map" class="w-5 h-5 text-white/50" />
                    <span class="text-sm">
                      <span class="font-bold text-white">{@org.stats.graphs}</span>
                      <span class="text-white/60">maps</span>
                    </span>
                  </div>
                  <div class="flex items-center gap-2">
                    <.icon name="hero-cursor-arrow-ripple" class="w-5 h-5 text-white/50" />
                    <span class="text-sm">
                      <span class="font-bold text-white">{@org.stats.explorations}</span>
                      <span class="text-white/60">explorations</span>
                    </span>
                  </div>
                </div>
              </div>
            </div>
          </section>

          <%!-- Query box --%>
          <section class="mb-12">
            <div class="mx-auto max-w-3xl">
              <div class={[
                "rounded-2xl shadow-xl border p-6 backdrop-blur-md",
                "bg-white/10 border-white/15"
              ]}>
                <h2 class="text-xl font-semibold text-white text-center mb-4">
                  <.icon name={@org.icon} class="w-5 h-5 inline-block mr-2 align-text-bottom" />
                  Start exploring with {@org.short_name}
                </h2>
                <.live_component
                  module={DialecticWeb.NewIdeaFormComp}
                  id="org-idea-form"
                  form={@form}
                  placeholder={"Ask a question in the #{@org.short_name} space..."}
                />
              </div>
            </div>
          </section>

          <%!-- About section --%>
          <section class="mb-12">
            <div class="rounded-2xl border border-white/15 bg-white/5 backdrop-blur-sm p-6 sm:p-8">
              <div class="flex flex-col md:flex-row gap-8">
                <div class="flex-1">
                  <h2 class="text-xl font-semibold text-white mb-3">
                    <.icon
                      name="hero-information-circle"
                      class="w-5 h-5 inline-block mr-2 align-text-bottom"
                    /> About this organisation
                  </h2>
                  <p class="text-white/70 leading-relaxed">{@org.long_description}</p>
                </div>

                <div class="md:w-64 flex-shrink-0">
                  <h3 class="text-sm font-semibold text-white/60 uppercase tracking-wide mb-3">
                    Focus Areas
                  </h3>
                  <div class="flex flex-wrap gap-2">
                    <%= for tag <- @org.tags do %>
                      <.link
                        navigate={~p"/?tag=#{tag}"}
                        class={[
                          "inline-flex items-center rounded-full px-3 py-1 text-xs font-medium ring-1 ring-inset transition-colors",
                          @org.accent_badge,
                          "hover:bg-white/10"
                        ]}
                      >
                        #{tag}
                      </.link>
                    <% end %>
                  </div>
                </div>
              </div>
            </div>
          </section>

          <%!-- Popular graphs --%>
          <section id="org-graphs">
            <div class="rounded-2xl border border-white/15 bg-white/10 backdrop-blur-md shadow-xl">
              <div class="p-5 sm:p-6">
                <div class="flex items-center justify-between">
                  <h2 class="text-xl sm:text-2xl font-semibold tracking-tight text-white">
                    <.icon
                      name="hero-fire"
                      class="w-6 h-6 inline-block mr-2 align-text-bottom text-orange-400"
                    /> Popular Maps
                  </h2>
                  <span class="text-sm text-white/50">
                    {length(@graphs)} maps
                  </span>
                </div>
              </div>

              <div class="border-t border-white/10">
                <div class="p-5 sm:p-6">
                  <%= if @graphs == [] do %>
                    <div class="text-center py-12">
                      <.icon name="hero-map" class="w-12 h-12 text-white/20 mx-auto mb-4" />
                      <p class="text-white/50 text-lg">No maps yet in this space.</p>
                      <p class="text-white/40 text-sm mt-1">
                        Be the first to explore a topic above!
                      </p>
                    </div>
                  <% else %>
                    <div class="columns-1 sm:columns-2 lg:columns-3 gap-6 space-y-6">
                      <%= for g <- @graphs do %>
                        <div class="break-inside-avoid">
                          <DialecticWeb.PageHtml.GraphComp.render
                            title={g.title}
                            is_public={g.is_public}
                            link={graph_path(g)}
                            count={0}
                            tags={g.tags}
                            node_count={
                              Enum.count(g.data["nodes"] || [], fn n ->
                                !Map.get(n, "compound", false)
                              end)
                            }
                            is_live={false}
                            generating={false}
                            id={"org-graph-#{g.slug || g.title}"}
                          />
                        </div>
                      <% end %>
                    </div>
                  <% end %>
                </div>
              </div>
            </div>
          </section>

          <%!-- CTA footer --%>
          <section class="mt-12 text-center">
            <div class="rounded-2xl border border-white/10 bg-white/5 backdrop-blur-sm p-8">
              <h2 class="text-2xl font-bold text-white mb-2">Want your own organisation space?</h2>
              <p class="text-white/60 mb-6 max-w-lg mx-auto">
                Get a dedicated MuDG space for your team, school, or research group — with custom branding, private maps, and collaborative tools.
              </p>
              <div class="flex flex-col sm:flex-row items-center justify-center gap-3">
                <.link
                  navigate={~p"/"}
                  class={[
                    "inline-flex items-center justify-center gap-2 rounded-xl px-6 py-3 text-sm font-semibold",
                    "bg-white text-slate-900 shadow-lg",
                    "hover:bg-white/90 transition"
                  ]}
                >
                  <.icon name="hero-envelope" class="w-5 h-5" /> Get in touch
                </.link>
                <.link
                  navigate={~p"/"}
                  class={[
                    "inline-flex items-center justify-center gap-2 rounded-xl px-6 py-3 text-sm font-semibold",
                    "bg-white/10 text-white ring-1 ring-white/20",
                    "hover:bg-white/15 transition"
                  ]}
                >
                  <.icon name="hero-arrow-left" class="w-5 h-5" /> Back to MuDG
                </.link>
              </div>
            </div>
          </section>
        </div>
      </div>
    </div>
    """
  end
end
