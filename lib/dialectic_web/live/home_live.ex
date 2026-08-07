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

    user = UserUtils.current_identity(socket.assigns)
    initial_content = params["initial_prompt"]

    changeset =
      GraphActions.create_new_node(user)
      |> Vertex.changeset(if initial_content, do: %{content: initial_content}, else: %{})

    prompt_mode = "university"

    {:ok,
     assign(socket,
       og_image: DialecticWeb.Endpoint.url() <> ~p"/images/graph_live.webp",
       page_title: "RationalGrid",
       user: user,
       form: to_form(changeset),
       prompt_mode: prompt_mode,
       ask_question: true,
       graph_id: nil,
       focus_new_grid: params["focus"] == "grid",
       preview_seed: home_preview_seed(),
       curated_grids: [],
       page_description:
         "Ask a question, map the answer, and challenge any branch while keeping its original context with RationalGrid."
     )}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    curated_grids =
      Graphs.list_curated_grids("curated", 20)
      |> preview_curated_grids(3, socket.assigns.preview_seed)

    {:noreply, assign(socket, :curated_grids, curated_grids)}
  end

  @impl true
  def handle_event("reply-and-answer", %{"vertex" => %{"content" => answer}} = params, socket) do
    mode_param = Map.get(params, "mode")
    {:noreply, submit_new_grid(socket, answer, mode_param)}
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
        <div class="mx-auto w-full max-w-3xl px-5 py-12 sm:px-8 sm:py-16">
          <div class="text-center">
            <p class="text-xs font-semibold uppercase tracking-[0.2em] text-teal-800">Start here</p>
            <h2 class="mt-3 font-serif text-4xl font-semibold leading-tight tracking-tight sm:text-5xl">
              What do you want to understand?
            </h2>
            <p class="mx-auto mt-3 max-w-xl text-base leading-7 text-slate-600">
              Your first answer becomes a map you can explore.
            </p>
          </div>

          <div
            id="home-start-panel"
            class="mt-7 border border-stone-300 bg-white p-4 shadow-sm sm:p-6"
          >
            <.live_component
              module={DialecticWeb.NewIdeaFormComp}
              id="new-idea-form"
              form={@form}
              placeholder="Ask a question or name a topic"
              submit_label="Continue"
              autofocus={@focus_new_grid}
              minimal={true}
            />
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
                Selected grids
              </p>
              <h2 class="mt-3 font-serif text-4xl font-semibold tracking-tight sm:text-5xl">
                Read a grid before you make one.
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

          <%= if @curated_grids != [] do %>
            <section id="curated" class="mt-8">
              <.curated_grid_section
                items={@curated_grids}
                title="Curated grids"
                pills={[]}
                id_prefix="home-curated"
              />
            </section>
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
    assigns = assign_new(assigns, :pills, fn -> [] end)

    ~H"""
    <section class="w-full min-w-0 border border-slate-300 bg-[#f4f1e9]">
      <div class="h-full">
        <div class="p-4 sm:p-5">
          <div class="mb-5 flex flex-col gap-3 border-b border-slate-300 pb-4 sm:flex-row sm:items-center sm:justify-between">
            <h2 class="text-lg font-semibold tracking-tight text-slate-950">{@title}</h2>
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
                show_badge={false}
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
end
