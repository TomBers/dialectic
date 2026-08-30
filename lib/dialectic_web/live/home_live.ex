defmodule DialecticWeb.HomeLive do
  use DialecticWeb, :live_view
  alias Dialectic.DbActions.Graphs
  alias Dialectic.Graph.GraphActions
  alias Dialectic.Graph.Vertex
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
        "Simple answers do not perform source research unless you ask for it. Expanded and In-depth answers are prompted to ground material claims in relevant primary, scholarly, or official sources, but AI can be wrong and important claims should be checked."
    },
    %{
      id: "chat-assistants",
      question: "Why not just use ChatGPT or Claude?",
      answer:
        "You can—and sometimes should. ChatGPT or Claude is often simpler for a quick answer, draft, or short conversation. RationalGrid is useful when the path matters: it keeps questions, sources, notes, and branches connected so you can return, check evidence, compare views, share, and build with others."
    }
  ]

  on_mount {DialecticWeb.UserAuth, :mount_current_user}

  @impl true
  def mount(params, session, socket) do
    socket =
      assign(socket,
        loading_graph: nil,
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
       preview_seed: home_preview_seed(),
       curated_grids: [],
       homepage_faqs: @homepage_faqs,
       json_ld: homepage_json_ld(),
       page_description:
         "For questions that matter, compare views, trace claims to sources, and keep your reasoning in a grid you can revisit and share."
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
  def handle_event("close_login_modal", _params, socket) do
    {:noreply, assign(socket, :show_level_login_modal, false)}
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
            redirect(socket, to: graph_path(existing_graph))
        end
    end
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

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-[#f4f1e9] font-sans text-slate-950 antialiased">
      <.login_required_modal
        id="answer-level-login-modal"
        show={@show_level_login_modal}
        title="Unlock deeper answer levels"
        description="Sign in to create grids with Expanded or In-depth answers, grounded sources, and deeper analysis."
      />

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

        <div class="mx-auto grid min-h-[72svh] w-full max-w-7xl items-center gap-12 px-5 py-16 sm:min-h-[78svh] sm:px-8 lg:grid-cols-[minmax(0,1.12fr)_minmax(22rem,0.72fr)] lg:px-10">
          <div class="max-w-4xl">
            <h1
              id="home-hero-title"
              class="flex items-start gap-4 text-white sm:gap-6"
            >
              <img
                id="home-hero-logo"
                src={~p"/images/brandmark.svg"}
                alt=""
                width="56"
                height="56"
                class="mt-1 h-8 w-8 shrink-0 sm:mt-2 sm:h-12 sm:w-12"
              />
              <span class="min-w-0">
                <span
                  id="home-hero-brand"
                  class="block text-4xl font-semibold leading-none tracking-[-0.035em] sm:text-6xl"
                >
                  RationalGrid
                </span>
                <span
                  id="home-hero-tagline"
                  class="mt-3 block text-2xl font-normal leading-none tracking-tight text-slate-300 sm:text-4xl"
                >
                  See what you think.
                </span>
              </span>
            </h1>
            <p
              id="home-hero-subheading"
              class="mt-8 text-lg leading-8 text-slate-200"
            >
              Know what you think—and show how you got there. Compare views, trace claims to sources,
              and keep the path open for you or others to question.
            </p>
            <div class="mt-12 flex flex-wrap items-center gap-4">
              <%= if @current_user do %>
                <.link
                  id="home-start-grid-link"
                  href="#start-here"
                  data-analytics-event="start_grid_clicked"
                  data-analytics-location="home_hero"
                  class="inline-flex items-center gap-2 rounded-md bg-teal-300 px-5 py-3 text-sm font-semibold text-slate-950 transition hover:bg-teal-200"
                >
                  Start a grid <.icon name="hero-arrow-down" class="h-4 w-4" />
                </.link>
              <% else %>
                <.link
                  id="home-sign-up-link"
                  navigate={~p"/users/register"}
                  data-analytics-event="sign_up_cta_clicked"
                  data-analytics-location="home_hero"
                  class="inline-flex items-center gap-2 rounded-md bg-teal-300 px-5 py-3 text-sm font-semibold text-slate-950 transition hover:bg-teal-200"
                >
                  Sign up free <.icon name="hero-arrow-right" class="h-4 w-4" />
                </.link>
              <% end %>
              <%= if @current_user do %>
                <.link
                  id="home-browse-examples-link"
                  navigate={~p"/community"}
                  data-analytics-event="community_clicked"
                  data-analytics-location="home_hero"
                  class="inline-flex items-center gap-2 border-b border-slate-400 px-1 py-2 text-sm font-semibold text-white transition hover:border-teal-300 hover:text-teal-200"
                >
                  Browse examples <.icon name="hero-arrow-right" class="h-4 w-4" />
                </.link>
              <% else %>
                <.link
                  id="home-explore-question-link"
                  href="#start-here"
                  data-analytics-event="explore_question_clicked"
                  data-analytics-location="home_hero"
                  class="inline-flex items-center gap-2 border-b border-slate-400 px-1 py-2 text-sm font-semibold text-white transition hover:border-teal-300 hover:text-teal-200"
                >
                  Explore a question <.icon name="hero-arrow-down" class="h-4 w-4" />
                </.link>
              <% end %>
              <.link
                id="home-about-link"
                navigate={~p"/about"}
                class="inline-flex items-center gap-2 border-b border-slate-400 px-1 py-2 text-sm font-semibold text-white transition hover:border-teal-300 hover:text-teal-200"
              >
                Why RationalGrid? <.icon name="hero-arrow-right" class="h-4 w-4" />
              </.link>
            </div>
            <p
              :if={is_nil(@current_user)}
              id="home-sign-up-reassurance"
              class="mt-4 text-sm text-slate-400"
            >
              Free account. No payment details. Save your grids, unlock deeper answers, and control access.
            </p>
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
          <div id="home-mobile-community-start" class="text-center md:hidden">
            <p class="text-xs font-semibold uppercase tracking-[0.2em] text-teal-800">
              Explore on mobile
            </p>
            <h2 class="mt-3 font-serif text-4xl font-semibold leading-tight tracking-tight">
              Follow a line of thought.
            </h2>
            <p class="mx-auto mt-4 max-w-md text-base leading-7 text-slate-600">
              RationalGrid is currently read-only on mobile. Browse public grids here, then use a
              larger screen when you want to create or edit one.
            </p>
            <.link
              id="home-mobile-community-link"
              navigate={~p"/community"}
              data-analytics-event="community_clicked"
              data-analytics-location="mobile_read_only_prompt"
              class="mt-6 inline-flex min-h-11 items-center gap-2 rounded-md bg-slate-950 px-5 py-3 text-sm font-semibold text-white transition hover:bg-slate-800"
            >
              Browse public grids <.icon name="hero-arrow-right" class="h-4 w-4" />
            </.link>
          </div>

          <div id="home-start-panel" class="hidden md:block">
            <div class="text-center">
              <p class="text-xs font-semibold uppercase tracking-[0.2em] text-teal-800">Try it</p>
              <h2 class="mt-3 font-serif text-4xl font-semibold leading-tight tracking-tight sm:text-5xl">
                Start with a question.
              </h2>
            </div>

            <div class="mt-7 rounded-xl bg-[linear-gradient(120deg,#2dd4bf_0%,#818cf8_52%,#fbbf24_100%)] p-[1px] shadow-[0_24px_60px_-38px_rgba(15,23,42,0.55)]">
              <div class="rounded-[calc(0.75rem-1px)] bg-white p-4 sm:p-6">
                <.live_component
                  module={DialecticWeb.NewIdeaFormComp}
                  id="new-idea-form"
                  form={@form}
                  placeholder="Ask a question or name a topic"
                  submit_label="Continue"
                  autofocus={@focus_new_grid}
                  minimal={true}
                  authenticated={!is_nil(@current_user)}
                  public_grid_warning="New grids are public and editable by default. Anyone can read them and, while editing is on, add to them. Sign in first if you want to control access in Settings; never include sensitive information."
                />
              </div>
            </div>
            <p class="mt-5 text-center text-sm text-slate-600">
              Prefer to look around first?
              <.link
                id="home-community-secondary-link"
                navigate={~p"/community"}
                data-analytics-event="community_clicked"
                data-analytics-location="question_form"
                class="font-semibold text-teal-800 underline decoration-teal-400 underline-offset-4 hover:text-teal-950"
              >
                Browse public grids
              </.link>
            </p>
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
            <p class="inline-flex rounded-full border border-teal-300/40 bg-teal-300/10 px-3 py-1.5 text-xs font-bold uppercase tracking-[0.14em] text-teal-100 shadow-sm">
              How RationalGrid supports learning
            </p>
            <ul
              id="home-learning-overview"
              class="mt-8 max-w-xl space-y-5 text-base leading-7 text-slate-300"
            >
              <li class="border-l-2 border-sky-400 pl-4">
                <strong class="text-white">Discover.</strong>
                Use AI to find new information and open paths worth investigating.
              </li>
              <li class="border-l-2 border-violet-400 pl-4">
                <strong class="text-white">Connect.</strong>
                Branch questions into answers, challenges, evidence, sources, and further questions.
              </li>
              <li class="border-l-2 border-teal-300 pl-4">
                <strong class="text-white">Recall.</strong>
                Bookmark nodes and highlight passages; they collect in
                <%= if @current_user do %>
                  <.link
                    id="home-saved-for-recall-link"
                    navigate={~p"/u/#{@current_user.username}" <> "#profile-thinking-library"}
                    class="font-semibold text-teal-200 underline decoration-teal-500 underline-offset-4 hover:text-teal-100"
                  >
                    Saved for recall
                  </.link>
                <% else %>
                  <span class="font-semibold text-teal-200">Saved for recall</span>
                <% end %>
                so the right idea is there when you need it.
              </li>
              <li class="border-l-2 border-amber-300 pl-4">
                <strong class="text-white">Share.</strong>
                Send a complete grid or a specific highlight so others can follow the idea in its
                original context.
              </li>
            </ul>
            <div class="mt-5 flex flex-wrap gap-x-5 gap-y-3">
              <.link
                id="home-features-link"
                navigate={~p"/about"}
                class="inline-flex items-center gap-2 border-b border-slate-500 pb-1 text-sm font-semibold text-white transition hover:border-teal-300 hover:text-teal-200"
              >
                Explore all features <.icon name="hero-arrow-right" class="h-4 w-4" />
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

      <.proof_carousel />

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
              <p class="inline-block border-l-2 border-teal-500 pl-3 text-sm font-bold uppercase tracking-[0.14em] text-teal-900">
                Curated grids
              </p>
              <h2 class="mt-3 font-serif text-4xl font-semibold tracking-tight sm:text-5xl">
                See what other people explored.
              </h2>
              <p id="home-community-learning" class="mt-3 max-w-2xl text-sm leading-6 text-slate-600">
                Find unfamiliar ideas, then question or extend any part.
              </p>
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

      <section id="home-definition" class="border-b border-slate-800 bg-slate-900 text-white">
        <div class="mx-auto w-full max-w-7xl px-5 py-10 sm:px-8 sm:py-12 lg:px-10">
          <h2 class="font-serif text-3xl font-semibold tracking-tight sm:text-4xl">
            What is RationalGrid?
          </h2>
          <p class="mt-4 max-w-3xl text-base leading-7 text-slate-300">
            RationalGrid is a free, not-for-profit, AI-assisted research and argument-mapping tool. It
            helps students and researchers organize claims and evidence into structured, shareable
            formats.
          </p>
        </div>
      </section>

      <section id="home-ai-limits-faq" class="border-b border-stone-300 bg-[#f4f1e9]">
        <div class="mx-auto w-full max-w-5xl px-5 py-12 sm:px-8 sm:py-16">
          <p class="text-xs font-semibold uppercase tracking-[0.2em] text-teal-800">
            Free to explore
          </p>
          <h2 class="mt-3 font-serif text-4xl font-semibold tracking-tight">
            AI and source limits
          </h2>
          <div class="mt-7 divide-y divide-stone-300 border-y border-stone-300">
            <details :for={faq <- @homepage_faqs} id={"home-faq-#{faq.id}"} class="group py-5">
              <summary class="flex cursor-pointer list-none items-center justify-between gap-4 font-semibold text-slate-950">
                {faq.question}
                <.icon
                  name="hero-plus"
                  class="h-5 w-5 shrink-0 text-teal-700 transition group-open:rotate-45"
                />
              </summary>
              <p class="mt-3 max-w-3xl text-sm leading-6 text-slate-600">{faq.answer}</p>
            </details>
          </div>
          <.link
            id="home-ai-limits-details-link"
            navigate={~p"/intro/ai"}
            class="mt-5 inline-flex items-center gap-2 border-b border-slate-500 pb-1 text-sm font-semibold text-slate-800 transition hover:border-teal-700 hover:text-teal-800"
          >
            Learn how AI and sources work <.icon name="hero-arrow-right" class="h-4 w-4" />
          </.link>
        </div>
      </section>

      <section id="home-final-cta" class="border-b border-slate-700 bg-slate-950 text-white">
        <div class="mx-auto flex w-full max-w-5xl flex-col gap-6 px-5 py-12 sm:flex-row sm:items-center sm:justify-between sm:px-8 sm:py-14">
          <div>
            <p class="text-xs font-semibold uppercase tracking-[0.2em] text-teal-300">
              Follow the reasoning
            </p>
            <h2 class="mt-2 font-serif text-3xl font-semibold tracking-tight sm:text-4xl">
              Start with a question that matters.
            </h2>
          </div>
          <%= if @current_user do %>
            <.link
              id="home-final-start-grid-link"
              href="#start-here"
              data-analytics-event="start_grid_clicked"
              data-analytics-location="home_final_cta"
              class="inline-flex shrink-0 items-center justify-center gap-2 rounded-md bg-teal-300 px-6 py-3.5 text-base font-semibold text-slate-950 transition hover:bg-teal-200"
            >
              Start a grid <.icon name="hero-arrow-up" class="h-4 w-4" />
            </.link>
          <% else %>
            <.link
              id="home-final-sign-up-link"
              navigate={~p"/users/register"}
              data-analytics-event="sign_up_cta_clicked"
              data-analytics-location="home_final_cta"
              class="inline-flex shrink-0 items-center justify-center gap-2 rounded-md bg-teal-300 px-6 py-3.5 text-base font-semibold text-slate-950 transition hover:bg-teal-200"
            >
              Sign up free <.icon name="hero-arrow-right" class="h-4 w-4" />
            </.link>
          <% end %>
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
            <p class="text-xs font-semibold uppercase tracking-[0.2em] text-teal-800">
              Evidence from the community
            </p>
            <h2 class="mt-2 font-serif text-3xl font-semibold tracking-tight sm:text-4xl">
              RationalGrid in use.
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
          <article
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
          </article>

          <figure
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
            <figcaption class="mt-6">
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
            </figcaption>
          </figure>
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
            "RationalGrid is a not-for-profit, open-source project for mapping questions, arguments, and sources.",
          "sameAs" => ["https://github.com/TomBers/dialectic"]
        },
        %{
          "@type" => ["Product", "SoftwareApplication"],
          "@id" => product_id,
          "name" => "RationalGrid",
          "url" => base_url,
          "image" => base_url <> ~p"/images/graph_live.webp",
          "description" =>
            "A free AI-assisted argument mapping tool for comparing views, tracing claims to sources, and sharing the reasoning behind a conclusion.",
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
