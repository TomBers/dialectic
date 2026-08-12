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
         "Turn AI answers into understanding you can keep. Connect questions, evidence, objections, and sources in a workspace you can revisit and share."
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
          class="absolute inset-0 -z-20 h-full w-full object-cover opacity-55 saturate-[1.15]"
          autoplay={true}
          muted={true}
          playsinline={true}
          preload="metadata"
          aria-hidden="true"
        >
          <source src={~p"/images/FractalBranchingTree.mp4"} type="video/mp4" />
        </video>
        <div class="absolute inset-0 -z-10 bg-[linear-gradient(90deg,rgba(2,6,23,0.94)_0%,rgba(2,6,23,0.72)_48%,rgba(2,6,23,0.54)_100%)]">
        </div>
        <div
          aria-hidden="true"
          class="absolute inset-0 -z-10 bg-[radial-gradient(circle_at_78%_24%,rgba(99,102,241,0.25),transparent_30%),radial-gradient(circle_at_18%_90%,rgba(20,184,166,0.20),transparent_34%),radial-gradient(circle_at_92%_86%,rgba(245,158,11,0.12),transparent_24%)]"
        >
        </div>
        <div
          aria-hidden="true"
          class="absolute inset-x-0 bottom-0 h-1 bg-[linear-gradient(90deg,#2dd4bf_0%,#818cf8_52%,#fbbf24_100%)]"
        >
        </div>

        <div class="mx-auto grid min-h-[72svh] w-full max-w-7xl items-center gap-12 px-5 py-16 sm:min-h-[78svh] sm:px-8 lg:grid-cols-[minmax(0,1.12fr)_minmax(22rem,0.72fr)] lg:px-10">
          <div class="max-w-4xl">
            <h1
              id="home-hero-title"
              class="text-balance font-serif text-5xl font-semibold leading-[0.98] tracking-tight text-white sm:text-7xl lg:text-[5.4rem]"
            >
              Explore with AI. Remember what you learn.
            </h1>
            <p class="mt-5 max-w-2xl text-balance text-lg leading-8 text-slate-200 sm:text-xl">
              RationalGrid brings fast AI exploration together with notes, highlights, and saved paths. Discover an idea, keep everything connected, and return when you need it.
            </p>
            <div class="mt-7 flex flex-wrap items-center gap-3">
              <.link
                href="#start-here"
                class="inline-flex items-center gap-2 rounded-md bg-teal-300 px-5 py-3 text-sm font-semibold text-slate-950 transition hover:bg-teal-200"
              >
                Map your first question <.icon name="hero-arrow-down" class="h-4 w-4" />
              </.link>
              <.link
                href="#popular-grids"
                class="inline-flex items-center gap-2 border-b border-slate-400 px-1 py-2 text-sm font-semibold text-white transition hover:border-teal-300 hover:text-teal-200"
              >
                Browse curated grids <.icon name="hero-arrow-down" class="h-4 w-4" />
              </.link>
            </div>
            <.link
              id="home-ai-scepticism-link"
              navigate={~p"/intro/ai"}
              class="group mt-4 inline-flex flex-wrap items-center gap-x-2 gap-y-1 text-sm text-slate-400 transition hover:text-slate-200"
            >
              <span class="font-semibold text-slate-200 group-hover:text-teal-200">
                Sceptical about AI?
              </span>
              <span>See where it helps—and where it can go wrong.</span>
              <.icon name="hero-arrow-right" class="h-4 w-4 transition group-hover:translate-x-0.5" />
            </.link>
          </div>

          <div class="hidden lg:block" aria-hidden="true">
            <div class="relative mx-auto max-w-md">
              <div class="absolute -inset-12 -z-10 bg-[radial-gradient(circle,rgba(45,212,191,0.13),transparent_62%)] blur-2xl">
              </div>
              <div class="border border-white/10 border-l-4 border-l-sky-400 bg-slate-900/80 px-5 py-4 shadow-2xl backdrop-blur-sm">
                <p class="text-[10px] font-bold uppercase tracking-[0.2em] text-sky-300">Question</p>
                <p class="mt-1 font-serif text-xl text-white">
                  What makes an explanation convincing?
                </p>
              </div>
              <div class="mx-auto h-9 w-px bg-slate-500"></div>
              <div class="relative grid grid-cols-2 gap-8 border-t border-slate-500 pt-9">
                <div class="absolute left-1/4 top-0 h-9 w-px bg-slate-500"></div>
                <div class="absolute right-1/4 top-0 h-9 w-px bg-slate-500"></div>
                <div class="border border-white/10 border-l-4 border-l-emerald-400 bg-slate-900/80 px-4 py-3 backdrop-blur-sm">
                  <p class="text-[10px] font-bold uppercase tracking-[0.2em] text-emerald-300">
                    Answer
                  </p>
                  <p class="mt-1 text-sm font-medium text-white">Evidence and reasoning</p>
                </div>
                <div class="border border-white/10 border-l-4 border-l-amber-400 bg-slate-900/80 px-4 py-3 backdrop-blur-sm">
                  <p class="text-[10px] font-bold uppercase tracking-[0.2em] text-amber-300">
                    Challenge
                  </p>
                  <p class="mt-1 text-sm font-medium text-white">Which assumption fails?</p>
                </div>
              </div>
              <div class="ml-auto mr-[12%] h-9 w-px bg-slate-500"></div>
              <div class="ml-auto w-[58%] border border-white/10 border-l-4 border-l-violet-400 bg-slate-900/80 px-4 py-3 backdrop-blur-sm">
                <p class="text-[10px] font-bold uppercase tracking-[0.2em] text-violet-300">Source</p>
                <p class="mt-1 text-sm font-medium text-white">Keep the evidence attached</p>
              </div>
            </div>
          </div>
        </div>
      </section>

      <section
        id="start-here"
        class="relative isolate overflow-hidden border-b border-stone-300 bg-[#f4f1e9]"
      >
        <div
          aria-hidden="true"
          class="absolute -left-28 top-10 -z-10 h-64 w-64 rounded-full bg-teal-200/35 blur-3xl"
        >
        </div>
        <div
          aria-hidden="true"
          class="absolute -right-28 bottom-0 -z-10 h-64 w-64 rounded-full bg-amber-200/35 blur-3xl"
        >
        </div>
        <div class="mx-auto w-full max-w-3xl px-5 py-12 sm:px-8 sm:py-16">
          <div class="text-center">
            <p class="text-xs font-semibold uppercase tracking-[0.2em] text-teal-800">Try it</p>
            <h2 class="mt-3 font-serif text-4xl font-semibold leading-tight tracking-tight sm:text-5xl">
              Ask your first question.
            </h2>
          </div>

          <div
            id="home-start-panel"
            class="mt-7 rounded-xl bg-[linear-gradient(120deg,#2dd4bf_0%,#818cf8_52%,#fbbf24_100%)] p-[1px] shadow-[0_24px_60px_-38px_rgba(15,23,42,0.55)]"
          >
            <div class="rounded-[calc(0.75rem-1px)] bg-white p-4 sm:p-6">
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
        </div>
      </section>

      <section
        id="home-exploration-tools"
        class="relative isolate overflow-hidden border-b border-stone-300 bg-[#fbfaf6]"
        aria-labelledby="home-exploration-tools-heading"
      >
        <div
          aria-hidden="true"
          class="absolute inset-x-0 top-0 -z-10 h-56 bg-[linear-gradient(180deg,rgba(45,212,191,0.08),transparent)]"
        >
        </div>
        <div class="mx-auto w-full max-w-7xl px-5 py-12 sm:px-8 sm:py-16 lg:px-10">
          <div class="grid gap-6 border-b border-slate-300 pb-8 lg:grid-cols-[minmax(0,0.82fr)_minmax(22rem,1.18fr)] lg:items-end">
            <div>
              <p class="text-xs font-semibold uppercase tracking-[0.2em] text-teal-800">
                Tools for exploration
              </p>
              <h2
                id="home-exploration-tools-heading"
                class="mt-3 font-serif text-4xl font-semibold tracking-tight sm:text-5xl"
              >
                Explore without losing the thread.
              </h2>
            </div>
            <p class="max-w-2xl text-lg leading-8 text-slate-700 lg:justify-self-end">
              Ask from any point, change the level, challenge an idea, or follow a new branch. Every path stays connected to the question that opened it.
            </p>
          </div>

          <div class="mt-8 grid gap-x-8 gap-y-7 md:grid-cols-2">
            <article id="home-feature-focused-inquiry" class="border-t-2 border-rose-500 pt-4">
              <div class="flex items-center gap-2.5">
                <.icon name="hero-cursor-arrow-rays" class="h-5 w-5 shrink-0 text-rose-700" />
                <h3 class="text-base font-semibold text-slate-950">Ask about anything</h3>
              </div>
              <p class="mt-2 max-w-xl text-sm leading-6 text-slate-600">
                Start from a whole idea or select a single word, passage, or book. The original text stays connected to your question.
              </p>
            </article>

            <article id="home-feature-levels" class="border-t-2 border-indigo-500 pt-4">
              <div class="flex items-center gap-2.5">
                <.icon name="hero-adjustments-horizontal" class="h-5 w-5 shrink-0 text-indigo-700" />
                <h3 class="text-base font-semibold text-slate-950">
                  Match the explanation level
                </h3>
              </div>
              <p class="mt-2 max-w-xl text-sm leading-6 text-slate-600">
                Choose Simple, High School, University, or Expert so every new answer uses the right language and depth.
              </p>
            </article>

            <article id="home-feature-critical-thinking" class="border-t-2 border-violet-500 pt-4">
              <div class="flex items-center gap-2.5">
                <.icon name="hero-arrows-right-left" class="h-5 w-5 shrink-0 text-violet-700" />
                <h3 class="text-base font-semibold text-slate-950">Examine the idea</h3>
              </div>
              <p class="mt-2 max-w-xl text-sm leading-6 text-slate-600">
                Define key words, ask for evidence, look for exceptions, and compare the strongest case for each side.
              </p>
            </article>

            <article
              id="home-feature-nonlinear-exploration"
              class="border-t-2 border-emerald-500 pt-4"
            >
              <div class="flex items-center gap-2.5">
                <.icon name="hero-squares-2x2" class="h-5 w-5 shrink-0 text-emerald-700" />
                <h3 class="text-base font-semibold text-slate-950">
                  Explore in any direction
                </h3>
              </div>
              <p class="mt-2 max-w-xl text-sm leading-6 text-slate-600">
                Hold many ideas, definitions, and branches without producing one long page of text. Open what matters and drill down wherever curiosity leads.
              </p>
            </article>
          </div>
        </div>
      </section>

      <section
        id="home-recall-tools"
        class="border-b border-stone-300 bg-white"
        aria-labelledby="home-recall-tools-heading"
      >
        <div class="mx-auto w-full max-w-7xl px-5 py-12 sm:px-8 sm:py-16 lg:px-10">
          <div class="grid gap-5 border-b border-slate-300 pb-7 lg:grid-cols-[minmax(0,0.82fr)_minmax(22rem,1.18fr)] lg:items-end">
            <div>
              <p class="text-xs font-semibold uppercase tracking-[0.2em] text-teal-800">
                Tools for recall
              </p>
              <h2
                id="home-recall-tools-heading"
                class="mt-3 font-serif text-4xl font-semibold tracking-tight sm:text-5xl"
              >
                Return without starting again.
              </h2>
            </div>
            <p class="max-w-2xl text-lg leading-8 text-slate-700 lg:justify-self-end">
              Highlights, stars, downloads, and updates turn useful work into something you can find and build on later.
            </p>
          </div>

          <div class="mt-8 grid gap-x-8 gap-y-7 md:grid-cols-2">
            <article id="home-feature-highlights" class="border-t-2 border-rose-500 pt-4">
              <div class="flex items-center gap-2.5">
                <.icon name="hero-bookmark" class="h-5 w-5 shrink-0 text-rose-700" />
                <h3 class="text-base font-semibold text-slate-950">Highlight what matters</h3>
              </div>
              <p class="mt-2 max-w-xl text-sm leading-6 text-slate-600">
                Save exact passages to your profile. Each gets its own link, while the original text stays with it.
              </p>
            </article>

            <article id="home-feature-stars" class="border-t-2 border-amber-500 pt-4">
              <div class="flex items-center gap-2.5">
                <.icon name="hero-star" class="h-5 w-5 shrink-0 text-amber-700" />
                <h3 class="text-base font-semibold text-slate-950">Star useful ideas</h3>
              </div>
              <p class="mt-2 max-w-xl text-sm leading-6 text-slate-600">
                Mark the ideas you want to revisit so the strongest parts of a large grid remain easy to find.
              </p>
            </article>

            <article id="home-feature-export" class="border-t-2 border-sky-500 pt-4">
              <div class="flex items-center gap-2.5">
                <.icon name="hero-arrow-down-tray" class="h-5 w-5 shrink-0 text-sky-700" />
                <h3 class="text-base font-semibold text-slate-950">
                  Export for further notes
                </h3>
              </div>
              <p class="mt-2 max-w-xl text-sm leading-6 text-slate-600">
                Download the grid for your notes, as an image to share, or as data for other tools.
              </p>
            </article>

            <article id="home-feature-shared-record" class="border-t-2 border-emerald-500 pt-4">
              <div class="flex items-center gap-2.5">
                <.icon name="hero-user-group" class="h-5 w-5 shrink-0 text-emerald-700" />
                <h3 class="text-base font-semibold text-slate-950">Keep a shared record</h3>
              </div>
              <p class="mt-2 max-w-xl text-sm leading-6 text-slate-600">
                Share or publish the grid, follow changes in Activity, and see who added each part.
              </p>
            </article>
          </div>
        </div>
      </section>

      <section
        id="home-product-preview"
        class="relative isolate overflow-hidden border-b border-slate-700 bg-slate-950 text-white"
      >
        <div
          aria-hidden="true"
          class="absolute inset-0 -z-10 bg-[radial-gradient(circle_at_82%_48%,rgba(56,189,248,0.12),transparent_34%),radial-gradient(circle_at_8%_88%,rgba(139,92,246,0.10),transparent_28%)]"
        >
        </div>
        <div class="mx-auto grid w-full max-w-7xl gap-10 px-5 py-12 sm:px-8 sm:py-16 lg:grid-cols-[minmax(20rem,0.72fr)_minmax(0,1.28fr)] lg:items-center lg:px-10">
          <div id="home-learning-loop">
            <p class="text-xs font-semibold uppercase tracking-[0.2em] text-teal-300">
              Explore + recall
            </p>
            <h2 class="mt-3 font-serif text-4xl font-semibold tracking-tight sm:text-5xl">
              Learning needs both.
            </h2>
            <p class="mt-4 max-w-xl text-base leading-7 text-slate-300">
              AI is great at opening new paths. Notes help you keep and revisit what matters. RationalGrid brings them together in one fast, visual loop.
            </p>
            <dl class="mt-7 grid gap-px overflow-hidden border border-slate-700 bg-slate-700 sm:grid-cols-2">
              <div id="home-learning-explore" class="bg-slate-950 p-5">
                <dt class="flex items-center gap-2 text-sm font-semibold text-sky-300">
                  <span class="flex h-6 w-6 items-center justify-center rounded-full border border-sky-400/50 text-[10px] font-bold">
                    01
                  </span>
                  Explore
                </dt>
                <dd class="mt-3 text-sm leading-6 text-slate-300">
                  Ask AI to explain or challenge an idea, compare views, and branch from any word or passage.
                </dd>
              </div>
              <div id="home-learning-recall" class="bg-slate-950 p-5">
                <dt class="flex items-center gap-2 text-sm font-semibold text-amber-300">
                  <span class="flex h-6 w-6 items-center justify-center rounded-full border border-amber-400/50 text-[10px] font-bold">
                    02
                  </span>
                  Recall
                </dt>
                <dd class="mt-3 text-sm leading-6 text-slate-300">
                  Highlight passages, add notes, star useful ideas, and return to the full path later.
                </dd>
              </div>
            </dl>
            <p
              id="home-learning-bridge"
              class="mt-4 border-l-2 border-teal-300 pl-4 text-sm leading-6 text-slate-300"
            >
              <span class="font-semibold text-white">The grid connects the two:</span>
              every question and note stays in place, ready to revisit or share.
            </p>
            <.link
              id="home-ai-exploration-link"
              navigate={~p"/intro/ai"}
              class="mt-5 inline-flex items-center gap-2 border-b border-slate-500 pb-1 text-sm font-semibold text-white transition hover:border-teal-300 hover:text-teal-200"
            >
              Why use AI for exploration? <.icon name="hero-arrow-right" class="h-4 w-4" />
            </.link>
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

      <section
        id="popular-grids"
        class="relative isolate overflow-hidden border-b border-stone-300 bg-[#fbfaf6]"
      >
        <div
          aria-hidden="true"
          class="absolute inset-x-0 top-0 -z-10 h-44 bg-[linear-gradient(180deg,rgba(45,212,191,0.08),transparent)]"
        >
        </div>
        <div class="mx-auto w-full max-w-7xl px-5 py-12 sm:px-8 sm:py-16 lg:px-10">
          <div class="flex flex-col gap-5 border-b border-slate-300 pb-6 sm:flex-row sm:items-end sm:justify-between">
            <div class="max-w-3xl">
              <p class="text-xs font-semibold uppercase tracking-[0.2em] text-teal-800">
                Curated grids
              </p>
              <h2 class="mt-3 font-serif text-4xl font-semibold tracking-tight sm:text-5xl">
                Build on good thinking.
              </h2>
            </div>
            <.link
              id="home-community-grids-link"
              navigate={~p"/community"}
              class="group inline-flex shrink-0 items-center gap-2 rounded-md bg-teal-300 px-6 py-3.5 text-base font-semibold text-slate-950 shadow-[0_18px_36px_-18px_rgba(13,148,136,0.8)] ring-1 ring-teal-500/30 transition hover:-translate-y-0.5 hover:bg-teal-200 hover:shadow-[0_22px_40px_-18px_rgba(13,148,136,0.9)] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-teal-600 focus-visible:ring-offset-2"
            >
              Browse community
              <.icon
                name="hero-arrow-right"
                class="h-4 w-4 transition-transform group-hover:translate-x-0.5"
              />
            </.link>
          </div>

          <%= if @curated_grids != [] do %>
            <section id="curated" class="mt-8">
              <.curated_grid_section items={@curated_grids} id_prefix="home-curated" />
            </section>
          <% end %>
        </div>
      </section>

      <section
        id="home-profile-section"
        class="relative isolate overflow-hidden border-b border-slate-700 bg-slate-900 text-white"
      >
        <div
          aria-hidden="true"
          class="absolute inset-0 -z-10 bg-[radial-gradient(circle_at_18%_12%,rgba(20,184,166,0.15),transparent_32%),radial-gradient(circle_at_88%_76%,rgba(245,158,11,0.10),transparent_25%)]"
        >
        </div>
        <div
          aria-hidden="true"
          class="absolute inset-x-0 top-0 h-1 bg-[linear-gradient(90deg,#2dd4bf_0%,#818cf8_52%,#fbbf24_100%)]"
        >
        </div>
        <div class="mx-auto grid w-full max-w-7xl gap-10 px-5 py-12 sm:px-8 sm:py-16 lg:grid-cols-[minmax(0,0.9fr)_minmax(22rem,0.65fr)] lg:items-center lg:px-10">
          <div>
            <p class="text-xs font-semibold uppercase tracking-[0.2em] text-teal-300">
              Public knowledge
            </p>
            <h2 class="mt-3 max-w-2xl font-serif text-4xl font-semibold tracking-tight sm:text-5xl">
              Share ideas people can build on.
            </h2>
            <p class="mt-4 max-w-2xl text-base leading-7 text-slate-300">
              Your profile keeps your public questions, grids, and themes in one place so other people can find, discuss, and build on them.
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
                  <p class="text-sm text-slate-400">Makes RationalGrid.ai</p>
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
            <.link navigate={~p"/intro/ai"} class="hover:text-white">AI and exploration</.link>
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
    ~H"""
    <section class="w-full min-w-0">
      <div id={"#{@id_prefix}-grids-list"} class="grid gap-5 md:grid-cols-2 xl:grid-cols-3">
        <%= for item <- @items do %>
          <.grid_card
            graph={item.graph}
            author_name={item.author_name}
            author_marker="@"
            id={@id_prefix <> "-" <> (item.graph.slug || "t-" <> Integer.to_string(:erlang.phash2(item.graph.title || "")))}
            variant={:curated}
            show_badge={false}
            tag_limit={3}
          />
        <% end %>
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
