defmodule DialecticWeb.HomeLive do
  use DialecticWeb, :live_view
  alias Dialectic.DbActions.Graphs
  alias Dialectic.Graph.GraphActions
  alias Dialectic.Graph.Vertex
  alias Dialectic.Learning
  alias DialecticWeb.Utils.UserUtils
  import DialecticWeb.GridCardComp
  require Logger

  @homepage_faqs [
    %{
      id: "cost",
      question: "How much does RationalGrid cost?",
      answer: "RationalGrid is free to use. There are no paid pricing tiers."
    },
    %{
      id: "ai-usage-limits",
      question: "What are the AI usage limits?",
      answer:
        "Signed-out visitors can use Simple answers. A free account unlocks Expanded and In-depth answers. Each person can have up to three AI requests in progress and make up to ten AI requests per minute; if a limit is reached, wait and try again."
    },
    %{
      id: "sources",
      question: "How does RationalGrid use sources?",
      answer:
        "Simple answers use general knowledge without live source research. Choose Expanded or In-depth for answers with source lookup; these levels are prompted to use relevant primary, scholarly, or official sources. AI can be wrong, so check important claims against the original sources."
    },
    %{
      id: "chat-assistants",
      question: "Why not just use ChatGPT or Claude?",
      answer:
        "RationalGrid keeps questions, answers, and sources connected in grids. Organise them by topic in My Learning, with bookmarks and highlights alongside. Return to an idea, check your understanding, and build on it.",
      comparisons_link?: true
    },
    %{
      id: "notion-obsidian",
      question: "Can I use RationalGrid with Notion or Obsidian?",
      answer:
        "Yes. Use RationalGrid to explore and structure a research question, then export the grid as Markdown and continue organising, linking, and writing in Notion or Obsidian.",
      notion_obsidian_link?: true
    }
  ]

  on_mount {DialecticWeb.UserAuth, :mount_current_user}

  @impl true
  def mount(params, session, socket) do
    socket =
      assign(socket,
        loading_graph: nil,
        existing_grid_choice: nil,
        show_level_login_modal: false,
        llm_actor_id: session["llm_actor_id"] || "home:#{socket.id}"
      )

    user = UserUtils.current_identity(socket.assigns)
    initial_content = params["initial_prompt"]

    changeset =
      GraphActions.create_new_node(user)
      |> Vertex.changeset(if initial_content, do: %{content: initial_content}, else: %{})

    prompt_mode = "high_school"

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
       learning_collection:
         Learning.get_collection(socket.assigns.current_user, params["collection"]),
       partner_grids_empty?: true,
       homepage_faqs: @homepage_faqs,
       json_ld: homepage_json_ld(),
       page_description:
         "An all-in-one AI learning workspace. Organise grids by topic, keep bookmarks and highlights alongside them, and find useful answers again in My Learning."
     )
     |> stream_configure(:partner_grids,
       dom_id: fn item ->
         "home-partner-" <>
           (item.graph.slug || Base.url_encode64(item.graph.title, padding: false))
       end
     )
     |> stream(:partner_grids, []), layout: false}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    grids = Graphs.list_curated_grids("featured", 3)

    {:noreply,
     socket
     |> assign(:partner_grids_empty?, grids == [])
     |> stream(:partner_grids, grids, reset: true)}
  end

  @impl true
  def handle_event("reply-and-answer", %{"vertex" => %{"content" => answer}} = params, socket) do
    mode_param = Map.get(params, "mode")
    {:noreply, submit_new_grid(socket, answer, mode_param)}
  end

  @impl true
  def handle_event("close_login_modal", _params, socket) do
    {:noreply, assign(socket, :show_level_login_modal, false)}
  end

  def handle_event("create_separate_grid", _params, socket) do
    case socket.assigns.existing_grid_choice do
      %{question: question, mode: mode} ->
        {:noreply,
         socket
         |> assign(existing_grid_choice: nil, prompt_mode: mode)
         |> begin_grid_creation(question)}

      nil ->
        {:noreply, socket}
    end
  end

  def handle_event("cancel_existing_grid", _params, socket) do
    {:noreply, assign(socket, existing_grid_choice: nil)}
  end

  @impl true
  def handle_async(:create_graph_flow, {:ok, {:ok, title}}, socket) do
    # Fetch the newly created graph to get its slug
    case Graphs.get_graph_by_title(title) do
      nil ->
        # This shouldn't happen since we just created the graph
        {:noreply, put_flash(socket, :error, "Grid not found after creation")}

      graph ->
        {:noreply,
         socket
         |> collect_created_grid(graph)
         |> push_event("analytics", %{
           event: "grid_created",
           params: %{
             answer_depth: socket.assigns.prompt_mode,
             user_state: if(socket.assigns.current_user, do: "authenticated", else: "anonymous")
           }
         })
         |> redirect(to: graph_path(graph))}
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
  def handle_info({:answer_level_login_required, _mode}, socket) do
    {:noreply, assign(socket, :show_level_login_modal, true)}
  end

  @impl true
  def handle_info({:submit_new_grid, answer, mode_param}, socket) do
    {:noreply, submit_new_grid(socket, answer, mode_param)}
  end

  @impl true
  def handle_info({:graph_creation_update, status}, socket) do
    loading = socket.assigns.loading_graph

    if loading do
      completed_steps =
        if loading.status in ["Initializing...", status] do
          loading.steps
        else
          loading.steps ++ [loading.status]
        end

      {:noreply,
       assign(socket, :loading_graph, %{
         loading
         | status: status,
           steps: completed_steps
       })}
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
        "simple" -> :high_school
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
      await_response: not Application.get_env(:dialectic, :sync_tasks_for_testing, false),
      progress_callback: fn status -> send(parent_pid, {:graph_creation_update, status}) end
    )
  end

  defp submit_new_grid(socket, answer, mode_param) do
    requested_mode = normalize_home_mode(mode_param || socket.assigns[:prompt_mode])

    if is_nil(socket.assigns[:current_user]) and requested_mode in ["university", "expert"] do
      assign(socket, :show_level_login_modal, true)
    else
      do_submit_new_grid(socket, answer, requested_mode)
    end
  end

  defp do_submit_new_grid(socket, answer, mode_param) do
    title = Graphs.sanitize_title(answer)
    socket = assign(socket, prompt_mode: mode_param)

    cond do
      socket.assigns.loading_graph != nil ->
        socket

      title == "untitled-idea" ->
        put_flash(socket, :error, "Please enter a question or topic.")

      true ->
        case Graphs.get_graph_by_title(title) do
          %{is_public: true, is_published: true, is_deleted: deleted?} = graph
          when deleted? != true ->
            assign(socket,
              existing_grid_choice: %{graph: graph, question: answer, mode: mode_param}
            )

          _ ->
            begin_grid_creation(socket, answer)
        end
    end
  end

  defp begin_grid_creation(socket, answer) do
    title = Graphs.sanitize_title(answer)
    parent_pid = self()
    prompt_mode = socket.assigns.prompt_mode
    current_user = socket.assigns.current_user
    actor_id = socket.assigns.llm_actor_id

    socket
    |> assign(:loading_graph, %{title: title, status: "Initializing...", steps: []})
    |> start_async(:create_graph_flow, fn ->
      create_graph_task(title, answer, prompt_mode, current_user, actor_id, parent_pid)
    end)
  end

  defp normalize_home_mode(mode) do
    case String.downcase(to_string(mode || "high_school")) do
      "expert" -> "expert"
      "university" -> "university"
      "high_school" -> "high_school"
      "simple" -> "high_school"
      _other -> "high_school"
    end
  end

  defp collect_created_grid(%{assigns: %{learning_collection: nil}} = socket, _graph), do: socket

  defp collect_created_grid(socket, graph) do
    case Learning.add_grid(
           socket.assigns.current_user,
           socket.assigns.learning_collection.id,
           graph.title
         ) do
      {:ok, _} ->
        socket

      {:error, _} ->
        put_flash(
          socket,
          :error,
          "Your grid was created, but could not be added to the collection. You can organise it in My Learning."
        )
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.home_content {assigns} />
    </Layouts.app>
    """
  end

  defp home_content(assigns) do
    ~H"""
    <div class="min-h-screen bg-[#f4f1e9] font-sans text-slate-950 antialiased">
      <.login_required_modal
        id="answer-level-login-modal"
        show={@show_level_login_modal}
        title="Unlock deeper answer levels"
        description="Sign in to create grids with Expanded or In-depth answers, grounded sources, and deeper analysis."
      />

      <.modal
        :if={@existing_grid_choice}
        id="existing-grid-choice"
        show
        on_cancel={JS.push("cancel_existing_grid")}
      >
        <div class="mx-auto w-full max-w-lg">
          <h2 id="existing-grid-choice-title" class="font-serif text-2xl font-semibold">
            This question has a public grid.
          </h2>
          <p id="existing-grid-choice-description" class="mt-3 text-sm leading-6 text-slate-600">
            Explore the existing discussion, or start a separate grid with your chosen answer depth.
          </p>
          <p class="mt-3 font-semibold">{@existing_grid_choice.graph.title}</p>
          <div class="mt-6 flex flex-wrap gap-3">
            <.link
              id="open-existing-grid"
              navigate={graph_path(@existing_grid_choice.graph)}
              class="rounded-md bg-slate-950 px-4 py-2 text-sm font-semibold text-white"
            >Open existing grid</.link>
            <button
              id="create-separate-grid"
              type="button"
              phx-click="create_separate_grid"
              class="rounded-md border border-slate-400 px-4 py-2 text-sm font-semibold"
            >Start a separate grid</button>
            <button
              id="cancel-existing-grid"
              type="button"
              phx-click="cancel_existing_grid"
              class="px-4 py-2 text-sm text-slate-600"
            >Cancel</button>
          </div>
        </div>
      </.modal>

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
        <img
          id="home-hero-background"
          src={~p"/images/fractal-branching-tree-1280.webp"}
          srcset={
            "#{~p"/images/fractal-branching-tree-768.webp"} 768w, #{~p"/images/fractal-branching-tree-1280.webp"} 1280w, #{~p"/images/fractal-branching-tree-1536.webp"} 1536w"
          }
          sizes="100vw"
          alt=""
          width="1536"
          height="850"
          fetchpriority="high"
          decoding="async"
          class="absolute inset-0 -z-20 h-full w-full object-cover opacity-55 saturate-[1.15]"
          aria-hidden="true"
        />
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

        <div class="mx-auto grid min-h-[72svh] w-full max-w-7xl items-center gap-12 px-5 py-16 sm:min-h-[78svh] sm:px-8 lg:grid-cols-[minmax(0,1.12fr)_minmax(22rem,0.72fr)] lg:items-start lg:px-10">
          <div class="max-w-4xl">
            <p class="flex items-center gap-3 text-xl font-semibold text-slate-200">
              <img
                id="home-hero-logo"
                src={~p"/images/brandmark.svg"}
                alt=""
                width="36"
                height="36"
                class="h-9 w-9 shrink-0"
              />
              <span id="home-hero-brand">RationalGrid</span>
            </p>
            <h1
              id="home-hero-title"
              class="mt-7 text-4xl font-semibold leading-[1.08] tracking-[-0.035em] text-white sm:text-5xl xl:text-6xl"
            >
              A home for everything <span class="block text-teal-200">you’re learning.</span>
            </h1>
            <p id="home-hero-subheading" class="mt-6 max-w-xl text-lg leading-8 text-slate-200">
              Explore questions with AI and other people. Organise your grids by subject in My Learning.
              Return to useful answers and build on them.
            </p>
            <div id="start-here" class="mt-7 scroll-mt-24">
              <div id="home-start-panel" class="max-w-xl">
                <label
                  id="home-question-label"
                  for="new-idea-input"
                  class="mb-3 block text-base font-semibold text-white"
                >
                  What would you like to learn?
                </label>
                <p
                  :if={@learning_collection}
                  id="home-collection-context"
                  class="mb-3 text-sm text-teal-200"
                >
                  Your new grid will be added to <strong>{@learning_collection.name}</strong>.
                  <.link
                    id="home-back-to-collection"
                    href={~p"/my/learning?collection=#{@learning_collection.id}"}
                    class="ml-2 underline"
                  >Back to collection</.link>
                </p>
                <div class="rounded-xl bg-white/10 p-2 text-slate-950 ring-1 ring-white/20">
                  <.live_component
                    module={DialecticWeb.NewIdeaFormComp}
                    id="new-idea-form"
                    form={@form}
                    placeholder="Ask a question or name a topic"
                    submit_label="Continue"
                    autofocus={@focus_new_grid}
                    minimal={true}
                    authenticated={!is_nil(@current_user)}
                    public_grid_warning="New grids are public and editable by default."
                  />
                </div>
              </div>
              <div class="mt-4 flex flex-wrap items-center gap-3">
                <.link
                  :if={@current_user}
                  id="home-my-learning-link"
                  href={~p"/my/learning"}
                  class="inline-flex min-h-11 items-center gap-2 rounded-md bg-teal-300 px-4 py-2 text-sm font-semibold text-slate-950 hover:bg-teal-200"
                >
                  <.icon name="hero-folder" class="h-4 w-4" /> Open My Learning
                </.link>
                <.link
                  id="home-community-secondary-link"
                  navigate={~p"/community"}
                  data-analytics-event="community_clicked"
                  data-analytics-location="home_hero"
                  class="inline-flex min-h-11 items-center gap-2 rounded-md border border-teal-200/60 bg-white/10 px-4 py-2 text-sm font-semibold text-teal-50 transition hover:bg-white/15 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-teal-300"
                >
                  Explore community grids <.icon name="hero-arrow-right" class="h-4 w-4" />
                </.link>
              </div>
              <p
                :if={is_nil(@current_user)}
                id="home-try-reassurance"
                class="mt-3 text-sm leading-6 text-slate-300"
              >
                Try Simple answers without an account.
                Sign up free to organise your grids, save bookmarks and highlights.
              </p>
            </div>
            <.link
              id="home-ai-scepticism-link"
              navigate={~p"/intro/ai"}
              class="group mt-5 inline-flex flex-wrap items-center gap-x-2 gap-y-1 text-sm text-slate-400 transition hover:text-slate-200"
            >
              <span class="font-semibold text-slate-200 group-hover:text-teal-200">
                Sceptical about AI?
              </span>
              <span>See where it helps—and where it can go wrong.</span>
              <.icon name="hero-arrow-right" class="h-4 w-4 transition group-hover:translate-x-0.5" />
            </.link>
          </div>

          <div id="home-grid-preview" class="mx-auto hidden w-full max-w-md lg:mt-16 lg:block">
            <h2
              id="home-grid-preview-title"
              class="mb-3 text-xs font-semibold uppercase tracking-[0.16em] text-teal-200"
            >
              Example grid
            </h2>
            <div class="overflow-hidden rounded-xl border border-white/20 bg-white text-slate-950 shadow-2xl">
              <div class="px-4 py-5 sm:px-5">
                <div class="rounded-lg border border-sky-200 border-l-4 border-l-sky-500 bg-sky-50 px-4 py-3">
                  <p class="text-xs font-semibold text-sky-800">Ask</p>
                  <p class="mt-1 text-base font-semibold">Does AI make us better thinkers?</p>
                </div>
                <div aria-hidden="true" class="mx-auto h-5 w-px bg-slate-300"></div>
                <div class="rounded-lg border border-teal-200 border-l-4 border-l-teal-500 bg-teal-50 px-4 py-3">
                  <p class="text-xs font-semibold text-teal-800">Answer</p>
                  <p class="mt-1 text-sm leading-6">
                    Better output and better thinking are different achievements.
                  </p>
                </div>
                <div aria-hidden="true" class="mx-auto h-5 w-px bg-slate-300"></div>
                <div class="relative -mx-1.5 grid grid-cols-2">
                  <div aria-hidden="true" class="absolute inset-x-1/4 top-0 border-t border-slate-300">
                  </div>
                  <div class="px-1.5">
                    <div aria-hidden="true" class="mx-auto h-5 w-px bg-slate-300"></div>
                    <div class="rounded-lg border border-amber-200 bg-amber-50 px-3 py-3">
                      <p class="text-xs font-semibold text-amber-800">Challenge</p>
                      <p class="mt-1 text-sm leading-6">Could AI make us less independent?</p>
                    </div>
                  </div>
                  <div class="px-1.5">
                    <div aria-hidden="true" class="mx-auto h-5 w-px bg-slate-300"></div>
                    <div class="rounded-lg border border-violet-200 bg-violet-50 px-3 py-3">
                      <p class="text-xs font-semibold text-violet-800">Explain a term</p>
                      <p class="mt-1 text-sm leading-6">What is “cognitive offloading”?</p>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      <.learning_journey current_user={@current_user} />

      <.proof_carousel />

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
            <h2
              id="home-product-preview-title"
              class="text-xs font-semibold uppercase tracking-[0.16em] text-teal-200"
            >
              Watch the tour
            </h2>
            <p id="home-visible-learning" class="mt-5 max-w-xl text-base leading-7 text-slate-300">
              AI is here. Make the learning visible: who asked, what was explored, and how ideas connect.
              Share a grid so others can follow the reasoning and build on it.
            </p>
            <div class="mt-5 flex flex-wrap gap-x-5 gap-y-3">
              <.link
                id="home-about-link"
                navigate={~p"/about"}
                class="inline-flex items-center gap-2 border-b border-slate-500 pb-1 text-sm font-semibold text-white transition hover:border-teal-300 hover:text-teal-200"
              >
                Why RationalGrid? <.icon name="hero-arrow-right" class="h-4 w-4" />
              </.link>
              <.link
                id="home-guide-link"
                navigate={~p"/intro/how"}
                class="inline-flex items-center gap-2 border-b border-slate-500 pb-1 text-sm font-semibold text-white transition hover:border-teal-300 hover:text-teal-200"
              >
                Read the guide <.icon name="hero-arrow-right" class="h-4 w-4" />
              </.link>
            </div>
          </div>

          <div class="border border-slate-700 bg-black p-2 shadow-2xl sm:p-3">
            <div
              id="home-example-video"
              class="relative aspect-video w-full overflow-hidden bg-slate-900"
              phx-hook="YouTubeFacade"
              phx-update="ignore"
              data-video-id="nZOqbspGPfY"
              data-video-title="RationalGrid product video"
            >
              <img
                src={~p"/images/rationalgrid-video-preview-768.webp"}
                srcset={
                  "#{~p"/images/rationalgrid-video-preview-768.webp"} 768w, #{~p"/images/rationalgrid-video-preview.webp"} 1280w"
                }
                sizes="(min-width: 1280px) 716px, (min-width: 1024px) 55vw, 100vw"
                alt="RationalGrid product video preview"
                width="768"
                height="432"
                class="h-full w-full object-cover"
                loading="lazy"
                decoding="async"
              />
              <button
                id="home-example-video-play"
                type="button"
                class="absolute inset-0 flex items-center justify-center bg-slate-950/30 text-white transition hover:bg-slate-950/45 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-teal-300"
                aria-label="Play RationalGrid product video"
              >
                <span class="flex h-16 w-16 items-center justify-center rounded-full bg-teal-300 text-slate-950 shadow-xl transition hover:scale-105">
                  <.icon name="hero-play-solid" class="ml-1 h-8 w-8" />
                </span>
              </button>
            </div>
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
              <h2
                id="home-community-title"
                class="inline-block border-l-2 border-teal-500 pl-3 text-sm font-bold uppercase tracking-[0.14em] text-teal-900"
              >
                Explore the community
              </h2>
            </div>
            <.link
              id="home-community-grids-link"
              navigate={~p"/community"}
              data-analytics-event="community_clicked"
              data-analytics-location="home_community"
              class="group inline-flex shrink-0 items-center gap-2 rounded-md bg-teal-300 px-6 py-3.5 text-base font-semibold text-slate-950 shadow-[0_18px_36px_-18px_rgba(13,148,136,0.8)] ring-1 ring-teal-500/30 transition hover:-translate-y-0.5 hover:bg-teal-200 hover:shadow-[0_22px_40px_-18px_rgba(13,148,136,0.9)] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-teal-600 focus-visible:ring-offset-2"
            >
              Explore community grids
              <.icon
                name="hero-arrow-right"
                class="h-4 w-4 transition-transform group-hover:translate-x-0.5"
              />
            </.link>
          </div>

          <section :if={!@partner_grids_empty?} id="home-partners" class="mt-8">
            <div
              id="home-partner-grids-list"
              phx-update="stream"
              class="grid gap-5 md:grid-cols-2 xl:grid-cols-3"
            >
              <%= for {id, item} <- @streams.partner_grids do %>
                <.grid_card
                  id={id}
                  graph={item.graph}
                  author_name={item.author_name}
                  author_marker="@"
                  variant={:partner}
                  label="Partner grid"
                  show_badge={false}
                  tag_limit={3}
                />
              <% end %>
            </div>
          </section>
        </div>
      </section>

      <section id="home-ai-limits-faq" class="border-b border-slate-800 bg-slate-900 text-white">
        <div class="mx-auto w-full max-w-5xl px-5 py-12 sm:px-8 sm:py-16">
          <h2
            id="home-faq-title"
            class="text-xs font-semibold uppercase tracking-[0.2em] text-teal-200"
          >
            FAQs
          </h2>

          <div class="mt-7 divide-y divide-slate-700 border-y border-slate-700">
            <details :for={faq <- @homepage_faqs} id={"home-faq-#{faq.id}"} class="group py-5">
              <summary class="flex cursor-pointer list-none items-center justify-between gap-4 font-semibold text-white">
                {faq.question}
                <.icon
                  name="hero-plus"
                  class="h-5 w-5 shrink-0 text-teal-300 transition group-open:rotate-45"
                />
              </summary>
              <p class="mt-3 w-full text-sm leading-6 text-slate-300">
                {faq.answer}
                <%= if Map.get(faq, :comparisons_link?, false) do %>
                  <.link
                    id="home-faq-comparisons-link"
                    navigate={~p"/compare"}
                    class="font-semibold text-teal-200 underline decoration-teal-400/50 underline-offset-4 hover:text-white"
                  >
                    See how RationalGrid compares with other tools and approaches.
                  </.link>
                <% end %>
                <%= if Map.get(faq, :notion_obsidian_link?, false) do %>
                  <.link
                    id="home-faq-notion-obsidian-link"
                    navigate={~p"/compare/notion-obsidian"}
                    class="font-semibold text-teal-200 underline decoration-teal-400/50 underline-offset-4 hover:text-white"
                  >
                    See the complete Notion and Obsidian research workflow.
                  </.link>
                <% end %>
              </p>
            </details>
          </div>
          <.link
            id="home-ai-limits-details-link"
            navigate={~p"/intro/ai"}
            class="mt-5 inline-flex items-center gap-2 border-b border-slate-500 pb-1 text-sm font-semibold text-white transition hover:border-teal-300 hover:text-teal-200"
          >
            Learn how AI and sources work <.icon name="hero-arrow-right" class="h-4 w-4" />
          </.link>
        </div>
      </section>

      <section id="home-final-cta" class="border-b border-stone-300 bg-[#f4f1e9] text-slate-950">
        <div class="mx-auto flex w-full max-w-5xl flex-col gap-6 px-5 py-12 sm:px-8 sm:py-14 lg:flex-row lg:items-center lg:justify-between">
          <div>
            <p class="text-xs font-semibold uppercase tracking-[0.2em] text-teal-800">
              A workspace that grows with you
            </p>
            <h2 class="mt-2 font-serif text-3xl font-semibold tracking-tight sm:text-4xl">
              Find an answer today. Build on it tomorrow.
            </h2>
            <p class="mt-3 max-w-xl text-sm leading-6 text-slate-600">
              Recall what you learned. Check it. Ask your next question.
            </p>
          </div>
          <div class="flex flex-col items-start gap-3 lg:max-w-sm lg:shrink-0 lg:items-end">
            <.start_grid_actions id="home-final" location="home_final_cta" />
            <%= if @current_user do %>
              <.link
                id="home-final-library-link"
                href={~p"/my/learning"}
                data-analytics-event="my_learning_clicked"
                data-analytics-location="home_final_cta"
                class="inline-flex min-h-11 items-center text-sm font-semibold text-slate-700 underline decoration-slate-500 underline-offset-4 hover:text-teal-800"
              >
                Open My Learning
              </.link>
            <% else %>
              <.link
                id="home-final-sign-up-link"
                navigate={~p"/users/register"}
                data-analytics-event="sign_up_cta_clicked"
                data-analytics-location="home_final_cta"
                class="inline-flex min-h-11 items-center text-sm font-semibold text-slate-700 underline decoration-slate-500 underline-offset-4 hover:text-teal-800"
              >
                Sign up free to save your discoveries
              </.link>
              <p class="text-xs text-slate-600">No payment details.</p>
            <% end %>
          </div>
        </div>
      </section>

      <footer class="bg-slate-950 text-slate-300">
        <div class="mx-auto flex w-full max-w-7xl flex-col gap-5 px-5 py-8 sm:flex-row sm:items-center sm:justify-between sm:px-8 lg:px-10">
          <div class="flex items-center gap-3">
            <img
              src={~p"/images/brandmark.svg"}
              alt="RationalGrid"
              width="56"
              height="56"
              class="h-7 w-7"
            />
            <div>
              <p class="font-semibold text-white">RationalGrid</p>
              <p class="text-xs text-slate-400">See what you think.</p>
            </div>
          </div>
          <nav aria-label="Homepage footer" class="flex flex-wrap gap-x-5 gap-y-2 text-sm">
            <.link navigate={~p"/intro/how"} class="hover:text-white">Guide</.link>
            <.link navigate={~p"/intro/ai"} class="hover:text-white">AI &amp; data use</.link>
            <.link navigate={~p"/about"} class="hover:text-white">About</.link>
            <.link navigate={~p"/community"} class="hover:text-white">Community</.link>
            <.link navigate={~p"/gallery"} class="hover:text-white">Gallery</.link>
            <.link
              id="home-footer-comparisons-link"
              navigate={~p"/compare"}
              class="hover:text-white"
            >
              Comparisons
            </.link>
            <.link
              id="home-footer-contact-link"
              href="mailto:hello@rationalgrid.ai"
              class="hover:text-white"
            >
              Contact
            </.link>
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

  attr :id, :string, required: true
  attr :location, :string, required: true

  defp start_grid_actions(assigns) do
    ~H"""
    <div id={"#{@id}-actions"} class="flex flex-wrap items-center gap-3">
      <.link
        id={"#{@id}-start-grid-link"}
        href="#start-here"
        phx-click={JS.focus(to: "#new-idea-input")}
        aria-controls="new-idea-input"
        data-analytics-event="start_grid_clicked"
        data-analytics-location={@location}
        class="inline-flex min-h-11 items-center justify-center gap-2 rounded-md bg-teal-800 px-5 py-3 text-sm font-semibold text-white transition hover:bg-teal-900 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-teal-800"
      >
        Start your own grid <.icon name="hero-arrow-up" class="h-4 w-4" />
      </.link>
      <.link
        id={"#{@id}-community-link"}
        navigate={~p"/community"}
        data-analytics-event="community_clicked"
        data-analytics-location={@location}
        class="inline-flex min-h-11 items-center justify-center gap-2 rounded-md border border-teal-800 px-5 py-3 text-sm font-semibold text-teal-800 transition hover:bg-teal-50 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-teal-800"
      >
        Explore community grids <.icon name="hero-arrow-right" class="h-4 w-4" />
      </.link>
    </div>
    """
  end

  defp learning_journey(assigns) do
    ~H"""
    <section
      id="home-learning-journey"
      aria-labelledby="home-learning-title"
      class="scroll-mt-8 border-b border-stone-200 bg-white"
    >
      <div class="mx-auto w-full max-w-7xl px-5 py-12 sm:px-8 sm:py-16 lg:px-10">
        <div class="max-w-3xl">
          <h2
            id="home-learning-title"
            class="text-xs font-semibold uppercase tracking-[0.18em] text-teal-800"
          >
            How it works
          </h2>
          <p id="home-learning-value" class="mt-4 text-lg leading-8 text-slate-700">
            ChatGPT can give you a great answer. But how will you find it a day, a month, or a year later?
          </p>
          <p id="home-learning-benefit" class="mt-4 text-base leading-7 text-slate-600">
            Recall an idea before reopening the answer: it strengthens memory and reveals gaps.
            Connect it to what you know to deepen your understanding.
          </p>
        </div>

        <ol id="home-learning-steps" class="mt-9 grid gap-8 md:grid-cols-3">
          <li id="home-learning-ask" class="flex min-w-0 flex-col border-t-2 border-sky-500 pt-5">
            <p class="text-xs font-bold uppercase tracking-[0.16em] text-sky-800">01 / Ask</p>
            <h3 class="mt-2 text-xl font-semibold">Find answers to your questions.</h3>
            <p class="mt-3 text-sm leading-6 text-slate-600">
              Ask a question. Your answer starts a grid of connected ideas.
            </p>
            <div class="mt-5 flex-1 rounded-lg border border-slate-200 bg-slate-50 p-5">
              <p class="text-xs font-semibold text-slate-500">An example starting point</p>
              <p class="mt-3 rounded-md border border-sky-200 bg-sky-50 px-3 py-3 text-sm font-semibold text-slate-900">
                Does AI make us better thinkers?
              </p>
              <div aria-hidden="true" class="ml-5 h-5 border-l border-slate-300"></div>
              <div class="ml-5 rounded-md border border-teal-200 bg-white px-3 py-3">
                <p class="text-xs font-semibold text-teal-800">An idea from the answer</p>
                <p class="mt-1 text-sm leading-6 text-slate-700">
                  Better output and better thinking are different achievements.
                </p>
              </div>
            </div>
          </li>
          <li
            id="home-learning-explore"
            class="flex min-w-0 flex-col border-t-2 border-violet-400 pt-5"
          >
            <p class="text-xs font-bold uppercase tracking-[0.16em] text-violet-800">02 / Explore</p>
            <h3 class="mt-2 text-xl font-semibold">Take ideas further, together.</h3>
            <p class="mt-3 text-sm leading-6 text-slate-600">
              Share a grid, add questions, and compare perspectives. Build on each other’s ideas.
            </p>
            <div class="mt-5 flex-1 rounded-lg border border-slate-200 bg-slate-50 p-5">
              <p class="text-xs font-semibold text-slate-500">Two directions from the same idea</p>
              <div class="mt-4 space-y-3 border-l border-slate-300 pl-3">
                <div class="rounded-md border border-amber-200 bg-amber-50 px-3 py-3">
                  <p class="text-xs font-semibold text-amber-800">Challenge the answer</p>
                  <p class="mt-1 text-sm leading-6 text-slate-800">
                    Could AI make us less independent?
                  </p>
                </div>
                <div class="rounded-md border border-violet-200 bg-violet-50 px-3 py-3">
                  <p class="text-xs font-semibold text-violet-800">Explain a term</p>
                  <p class="mt-1 text-sm leading-6 text-slate-800">What is “cognitive offloading”?</p>
                </div>
              </div>
            </div>
          </li>
          <li id="home-learning-return" class="flex min-w-0 flex-col border-t-2 border-teal-500 pt-5">
            <p class="text-xs font-bold uppercase tracking-[0.16em] text-teal-800">
              03 / Organise & return
            </p>
            <h3 class="mt-2 text-xl font-semibold">Keep your learning organised.</h3>
            <p class="mt-3 text-sm leading-6 text-slate-600">
              Keep related grids, bookmarks, and highlights together in My Learning.
              Return to a topic and take your next step.
            </p>
            <div
              id="home-return-tools"
              class="mt-5 flex-1 rounded-lg border border-slate-200 bg-white p-5"
            >
              <p class="text-xs font-semibold text-slate-500">My Learning</p>
              <ul class="mt-4 space-y-4 text-sm leading-6">
                <li class="flex items-start gap-3">
                  <.icon name="hero-folder" class="mt-1 h-4 w-4 shrink-0 text-teal-700" />
                  <span><strong class="block text-slate-900">Subject collections</strong><span class="text-slate-600">Topics from your tags. Drag grids into collections.</span></span>
                </li>
                <li class="flex items-start gap-3">
                  <.icon name="hero-magnifying-glass" class="mt-1 h-4 w-4 shrink-0 text-teal-700" />
                  <span><strong class="block text-slate-900">Search</strong><span class="text-slate-600">Find grids by title or tag.</span></span>
                </li>
                <li class="flex items-start gap-3">
                  <.icon name="hero-pencil" class="mt-1 h-4 w-4 shrink-0 text-amber-700" />
                  <span><strong class="block text-slate-900">Highlights</strong><span class="text-slate-600">Keep useful passages.</span></span>
                </li>
                <li class="flex items-start gap-3">
                  <.icon name="hero-bookmark" class="mt-1 h-4 w-4 shrink-0 text-violet-700" />
                  <span><strong class="block text-slate-900">Bookmarks</strong><span class="text-slate-600">Save answers to revisit in context.</span></span>
                </li>
              </ul>
              <p id="home-recall-account-note" class="mt-5 text-sm leading-6 text-slate-600">
                Keep it all in My Learning with a free account.
                <.link
                  :if={@current_user}
                  id="home-learning-workspace-link"
                  href={~p"/my/learning"}
                  class="font-semibold text-teal-800 underline decoration-teal-500 underline-offset-4 hover:text-teal-950"
                >
                  Open My Learning
                </.link>
              </p>
            </div>
          </li>
        </ol>
        <div class="mt-7 border-t border-slate-200 pt-5">
          <.start_grid_actions id="home-learning" location="home_learning_journey" />
        </div>
      </div>
    </section>
    """
  end

  defp proof_carousel(assigns) do
    ~H"""
    <section
      id="home-proof-carousel"
      class="border-b border-stone-300 bg-[#f4f1e9]"
      phx-hook="ProofCarousel"
      phx-update="ignore"
      aria-label="RationalGrid in use"
    >
      <div class="mx-auto w-full max-w-6xl px-5 py-12 sm:px-8 sm:py-16 lg:px-10">
        <div class="flex items-end justify-between gap-6 border-b border-stone-300 pb-5">
          <div>
            <h2
              id="home-proof-title"
              class="text-xs font-semibold uppercase tracking-[0.2em] text-teal-800"
            >
              RationalGrid in use
            </h2>
          </div>
          <div class="flex shrink-0 items-center gap-2">
            <button
              id="home-proof-previous"
              type="button"
              data-carousel-previous
              class="inline-flex h-10 w-10 items-center justify-center rounded-full border border-stone-400 bg-white text-slate-800 transition hover:border-teal-700 hover:text-teal-800 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-teal-700"
              aria-label="Previous proof"
            >
              <.icon name="hero-arrow-left" class="h-4 w-4" />
            </button>
            <button
              id="home-proof-next"
              type="button"
              data-carousel-next
              class="inline-flex h-10 w-10 items-center justify-center rounded-full border border-stone-400 bg-white text-slate-800 transition hover:border-teal-700 hover:text-teal-800 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-teal-700"
              aria-label="Next proof"
            >
              <.icon name="hero-arrow-right" class="h-4 w-4" />
            </button>
          </div>
        </div>

        <div class="mt-8" data-carousel-slides>
          <div
            id="home-research-case-study"
            data-carousel-slide
            role="group"
            aria-roledescription="slide"
            aria-label="1 of 2"
            class="grid gap-7 lg:grid-cols-[15rem_minmax(0,1fr)]"
          >
            <div>
              <p class="text-xs font-semibold uppercase tracking-[0.2em] text-teal-800">
                Research case study
              </p>
              <h3 class="mt-3 font-serif text-3xl font-semibold tracking-tight">
                How
                <a
                  id="home-case-study-heading-organization-link"
                  href="https://philosophynow.org/"
                  target="_blank"
                  rel="noopener noreferrer"
                  class="text-teal-800 underline decoration-teal-500 underline-offset-4 transition hover:text-teal-950 hover:decoration-teal-700"
                >Philosophy Now</a>
                mapped one article into 35 connected ideas.
              </h3>
            </div>
            <div class="border-l-2 border-teal-600 pl-5 sm:pl-7">
              <p class="text-base leading-7 text-slate-700">
                <a
                  id="home-case-study-organization-link"
                  href="https://philosophynow.org/"
                  target="_blank"
                  rel="noopener noreferrer"
                  class="font-semibold text-slate-900 underline decoration-stone-400 underline-offset-4 hover:decoration-teal-700 hover:text-teal-800"
                >Philosophy Now</a>
                began with physicist and former semiconductor researcher Ignacio Gonzalez’s article
                about why some narratives spread and survive. Using RationalGrid, it turned the
                argument into a 35-point map branching into memetic fitness, human agency,
                psychological susceptibility, narrative complexity, talking points, and moral
                motivation. The result keeps competing explanations and follow-up questions
                connected, giving readers paths to inspect instead of a single linear summary.
              </p>
              <div class="mt-5 flex flex-wrap gap-5 text-sm font-semibold">
                <a
                  id="home-case-study-grid-link"
                  href="https://rationalgrid.ai/g/inspired-by-the-philosophy-now-article-a-memetic-664759?node=1"
                  data-analytics-event="case_study_clicked"
                  data-analytics-location="home_proof_carousel"
                  class="inline-flex items-center gap-2 border-b border-slate-500 pb-1 text-slate-900 hover:border-teal-700 hover:text-teal-800"
                >
                  Explore the 35-point grid <.icon name="hero-arrow-up-right" class="h-4 w-4" />
                </a>
                <a
                  id="home-case-study-source-link"
                  href="https://philosophynow.org/issues/173/A_Memetic_Analysis_of_Narratives_and_Conspiracies"
                  target="_blank"
                  rel="noopener noreferrer"
                  class="inline-flex items-center gap-2 border-b border-slate-500 pb-1 text-slate-900 hover:border-teal-700 hover:text-teal-800"
                >
                  Read the source article <.icon name="hero-arrow-up-right" class="h-4 w-4" />
                </a>
              </div>
            </div>
          </div>

          <div
            id="home-testimonial"
            data-carousel-slide
            role="group"
            aria-roledescription="slide"
            aria-label="2 of 2"
            class="hidden border-l-4 border-teal-500 pl-6 sm:pl-8"
            hidden
          >
            <blockquote class="max-w-4xl font-serif text-xl leading-relaxed text-slate-800 sm:text-2xl">
              “An amazing free specialised AI tool to explore philosophical ideas around pretty much
              anything—from academic questions to films to… hamsters! All at one’s fingertips, in a
              matter of seconds, with in-built tools for a sophisticated, yet accessible dialectic.
              Bravo!”
            </blockquote>
            <div class="mt-6" data-testimonial-attribution>
              <div class="flex flex-wrap items-baseline gap-x-2 gap-y-1">
                <span class="text-lg font-bold text-slate-950">Alexandra Konoplyanik</span>
                <span class="text-slate-400" aria-hidden="true">—</span>
                <a
                  id="home-testimonial-organization-link"
                  href="https://pfalondon.org/"
                  target="_blank"
                  rel="noopener noreferrer"
                  class="font-bold text-teal-800 underline decoration-teal-500 underline-offset-4 transition hover:text-teal-950 hover:decoration-teal-700"
                >Philosophy for All</a>
              </div>
              <p class="mt-1 text-sm text-slate-600">RationalGrid adviser</p>
            </div>
          </div>
        </div>

        <div class="mt-7 flex items-center justify-center gap-3" aria-label="Choose proof slide">
          <button
            type="button"
            data-carousel-indicator="0"
            class="h-2.5 w-8 rounded-full bg-teal-700 transition"
            aria-label="Show research case study"
            aria-current="true"
          ></button>
          <button
            type="button"
            data-carousel-indicator="1"
            class="h-2.5 w-8 rounded-full bg-stone-300 transition"
            aria-label="Show testimonial"
            aria-current="false"
          ></button>
          <span class="sr-only" data-carousel-status aria-live="polite">1 of 2</span>
        </div>
      </div>
    </section>
    """
  end

  defp homepage_json_ld do
    base_url = DialecticWeb.Endpoint.url()
    organization_id = base_url <> "/#organization"
    product_id = base_url <> "/#product"

    Jason.encode!(%{
      "@context" => "https://schema.org",
      "@graph" => [
        %{
          "@type" => "Organization",
          "@id" => organization_id,
          "name" => "RationalGrid",
          "url" => base_url,
          "logo" => base_url <> ~p"/images/brandmark.svg",
          "description" =>
            "RationalGrid is a not-for-profit project for mapping questions, arguments, and sources.",
          "sameAs" => ["https://github.com/TomBers/dialectic"]
        },
        %{
          "@type" => "SoftwareApplication",
          "@id" => product_id,
          "name" => "RationalGrid",
          "url" => base_url,
          "image" => base_url <> ~p"/images/graph_live.webp",
          "description" =>
            "An all-in-one AI learning workspace. Explore questions, organise grids into subject collections, and find your answers, bookmarks, and highlights together in My Learning.",
          "applicationCategory" => "EducationalApplication",
          "operatingSystem" => "Web",
          "isAccessibleForFree" => true,
          "brand" => %{"@id" => organization_id},
          "offers" => %{
            "@type" => "Offer",
            "url" => base_url,
            "price" => "0.00",
            "priceCurrency" => "USD",
            "availability" => "https://schema.org/InStock"
          }
        },
        %{
          "@type" => "FAQPage",
          "@id" => base_url <> "/#ai-and-source-limits",
          "mainEntity" =>
            Enum.map(@homepage_faqs, fn faq ->
              %{
                "@type" => "Question",
                "name" => faq.question,
                "acceptedAnswer" => %{
                  "@type" => "Answer",
                  "text" => faq.answer
                }
              }
            end)
        }
      ]
    })
  end
end
