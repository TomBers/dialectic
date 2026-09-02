defmodule DialecticWeb.NodeComp do
  use DialecticWeb, :live_component

  alias Dialectic.Responses.GuidedLearningPlan
  alias DialecticWeb.GraphHelpers
  alias DialecticWeb.GridCardComp

  @impl true
  def update(assigns, socket) do
    base_node =
      case Map.get(assigns, :node) do
        %{} = n -> n
        _ -> %{}
      end

    # Normalize required fields so template can use @node.id/content/children/parents directly
    node =
      base_node
      |> Map.put_new(:id, "")
      |> Map.put_new(:content, "")
      |> Map.put_new(:class, "")
      |> Map.put_new(:children, [])
      |> Map.put_new(:parents, [])

    node_id = Map.get(node, :id, "")
    guided_actions = guided_options(assigns, :guided_actions, node, &GuidedLearningPlan.actions/1)
    guided_paths = guided_options(assigns, :guided_paths, node, &GuidedLearningPlan.paths/1)

    {:ok,
     assign(socket,
       node_id: node_id,
       node: node,
       user: Map.get(assigns, :user),
       form: Map.get(assigns, :form),
       cut_off: Map.get(assigns, :cut_off, 500),
       ask_question: Map.get(assigns, :ask_question, true),
       prompt_mode: Map.get(assigns, :prompt_mode, "university"),
       graph_id: Map.get(assigns, :graph_id, ""),
       graph_struct: Map.get(assigns, :graph_struct),
       graph_owner_id: Map.get(assigns, :graph_owner_id),
       current_user: Map.get(assigns, :current_user),
       can_edit: Map.get(assigns, :can_edit, true),
       menu_visible: Map.get(assigns, :menu_visible, true),
       streaming: Map.get(assigns, :streaming, false),
       guided_actions: guided_actions,
       guided_paths: guided_paths,
       guided_path_form: Map.get(assigns, :guided_path_form, to_form(%{}, as: :guided_paths)),
       max_explore_items: Map.get(assigns, :max_explore_items, 3),
       presentation_mode: Map.get(assigns, :presentation_mode, :off),
       token: Map.get(assigns, :token)
     )}
  end

  @regeneratable_classes [
    "thesis",
    "antithesis",
    "ideas",
    "answer",
    "learning_plan",
    "explain",
    "synthesis",
    "clarify",
    "assumptions",
    "counterexample",
    "implications",
    "blind_spots",
    "says_who",
    "who_disagrees",
    "steel_man",
    "what_if"
  ]

  defp show_regenerate_cta?(%{id: id, class: class}) when is_binary(id) and is_binary(class) do
    id != "" and id != "start" and class in @regeneratable_classes
  end

  defp show_regenerate_cta?(_node), do: false

  defp node_title_size_class(%{content: content}) when is_binary(content) do
    case title_text_length(content) do
      length when length >= 96 -> "text-[15px] sm:text-base md:text-[1.05rem]"
      length when length >= 64 -> "text-base sm:text-[1.05rem] md:text-lg"
      _length -> "text-lg sm:text-[1.15rem] md:text-[1.35rem]"
    end
  end

  defp node_title_size_class(_node), do: "text-lg sm:text-[1.15rem] md:text-[1.35rem]"

  defp title_text_length(content) do
    content
    |> String.replace(~r/\r\n|\r/, "\n")
    |> String.trim_leading()
    |> String.split("\n", parts: 2)
    |> List.first()
    |> to_string()
    |> String.replace(~r/^\s*\#{1,6}\s*/, "")
    |> String.replace(~r/^\s*title\b\s*:?\s*/i, "")
    |> String.replace("**", "")
    |> String.trim()
    |> String.length()
  end

  defp existing_follow_up_questions_json(%{children: children}) when is_list(children) do
    children
    |> Enum.filter(fn child ->
      Map.get(child, :class) == "question" and not Map.get(child, :deleted, false)
    end)
    |> Enum.map(fn child ->
      child
      |> Map.get(:content, "")
      |> to_string()
      |> String.trim()
    end)
    |> Enum.reject(&(&1 == ""))
    |> Jason.encode!()
  end

  defp existing_follow_up_questions_json(_node), do: "[]"

  defp guided_options(assigns, key, node, fallback) do
    case Map.get(assigns, key, []) do
      [] ->
        case GuidedLearningPlan.normalize(Map.get(node, :guided_plan)) do
          {:ok, plan} ->
            plan
            |> fallback.()
            |> Enum.map(&Map.put_new(&1, :disabled, false))

          {:error, _errors} ->
            []
        end

      options ->
        options
    end
  end

  defp interactive_learning_plan?(%{class: "learning_plan"} = node) do
    match?({:ok, _plan}, GuidedLearningPlan.normalize(Map.get(node, :guided_plan)))
  end

  defp interactive_learning_plan?(_node), do: false

  defp learning_plan(assigns) do
    ~H"""
    <div id={"guided-learning-plan-#{@node.id}"} class="not-prose space-y-7 pb-3 pt-1">
      <section id="guided-plan-actions">
        <div class="flex items-end justify-between gap-4">
          <div>
            <h3 class="font-serif text-lg font-semibold leading-6 text-slate-950">
              Best next actions
            </h3>
            <p class="mt-0.5 text-xs leading-5 text-slate-500">
              Choose one to continue immediately.
            </p>
          </div>
          <span class="hidden text-[10px] font-semibold uppercase tracking-[0.14em] text-slate-400 sm:block">
            One action
          </span>
        </div>

        <div class="mt-3 grid gap-3">
          <%= for {recommendation, index} <- Enum.with_index(@guided_actions) do %>
            <% action_disabled = recommendation.disabled || !@can_edit %>
            <button
              id={"guided-plan-action-#{index}"}
              type="button"
              phx-click="apply_guided_next_action"
              phx-value-action={recommendation.action}
              phx-value-id={@node.id}
              disabled={action_disabled}
              aria-disabled={to_string(action_disabled)}
              aria-describedby={"guided-plan-action-tooltip-#{index}"}
              class={[
                "group flex w-full flex-col rounded-2xl border p-4 text-left shadow-sm transition duration-200 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-indigo-500 focus-visible:ring-offset-2",
                action_disabled && "cursor-not-allowed border-slate-200 bg-slate-100/80",
                !action_disabled && recommendation.recommended &&
                  "border-indigo-300 bg-gradient-to-br from-indigo-50 via-white to-white ring-1 ring-indigo-100 hover:border-indigo-400 hover:shadow-md",
                !action_disabled && !recommendation.recommended &&
                  "border-slate-200 bg-white hover:border-slate-300 hover:shadow-md"
              ]}
            >
              <span class="flex w-full items-start justify-between gap-2">
                <span class="flex min-w-0 items-start gap-2.5">
                  <span class="group/tool relative shrink-0">
                    <span
                      data-guided-action-icon={recommendation.action}
                      class={[
                        "inline-flex h-8 w-8 items-center justify-center rounded-lg shadow-sm ring-1 ring-inset ring-black/5",
                        DialecticWeb.ColUtils.advanced_tool_icon_class(recommendation.action)
                      ]}
                    >
                      <.icon name={recommendation.icon} class="h-4 w-4" />
                    </span>
                    <span id={"guided-plan-action-tooltip-#{index}"} role="tooltip" class="sr-only">
                      {recommendation.tool_description}
                    </span>
                    <span
                      aria-hidden="true"
                      class="pointer-events-none invisible absolute bottom-full left-0 z-30 mb-2 w-52 rounded-lg bg-slate-950 px-3 py-2 text-xs font-medium leading-4 text-white opacity-0 shadow-xl transition-opacity group-hover/tool:visible group-hover/tool:opacity-100"
                    >
                      {recommendation.tool_description}
                    </span>
                  </span>
                  <span class={[
                    "min-w-0 pt-1 text-sm font-semibold leading-5",
                    if(action_disabled, do: "text-slate-500", else: "text-slate-950")
                  ]}>
                    {recommendation.label}
                  </span>
                </span>
                <span
                  :if={recommendation.recommended}
                  class="shrink-0 rounded-full bg-indigo-700 px-2 py-0.5 text-[9px] font-bold uppercase tracking-wide text-white"
                >
                  Recommended
                </span>
                <span
                  :if={recommendation.disabled}
                  class="shrink-0 rounded-full bg-slate-200 px-2 py-0.5 text-[9px] font-bold uppercase tracking-wide text-slate-500"
                >
                  Already asked
                </span>
              </span>
              <span class={[
                "mt-2 block text-sm leading-5",
                if(action_disabled, do: "text-slate-500", else: "text-slate-600")
              ]}>
                {recommendation.reason}
              </span>
              <span
                :if={!action_disabled}
                class="mt-3 inline-flex items-center gap-1.5 text-xs font-semibold text-indigo-700"
              >
                Continue <.icon name="hero-arrow-right" class="h-3.5 w-3.5" />
              </span>
            </button>
          <% end %>
        </div>
      </section>

      <section :if={@guided_paths != []} id="guided-plan-paths" class="border-t border-slate-200 pt-6">
        <div>
          <h3 class="font-serif text-lg font-semibold leading-6 text-slate-950">Paths to explore</h3>
          <p class="mt-0.5 text-xs leading-5 text-slate-500">
            Select up to {@max_explore_items}. Each path creates one AI request.
          </p>
        </div>

        <.form
          for={@guided_path_form}
          id="guided-plan-path-form"
          phx-submit="submit_guided_paths"
          class="mt-3 space-y-3"
        >
          <%= for path <- @guided_paths do %>
            <% path_disabled = path.disabled || !@can_edit %>
            <div
              id={"guided-plan-path-#{path.id}"}
              class={[
                "rounded-2xl border p-4 shadow-sm transition",
                if(path_disabled,
                  do: "border-slate-200 bg-slate-100/80",
                  else:
                    "border-slate-200 bg-white hover:border-indigo-300 has-[:checked]:border-indigo-400 has-[:checked]:bg-indigo-50/70 has-[:checked]:ring-1 has-[:checked]:ring-indigo-200"
                )
              ]}
            >
              <div class="flex items-start justify-between gap-3">
                <.input
                  type="checkbox"
                  id={"guided-plan-path-checkbox-#{path.id}"}
                  name={"paths[#{path.id}]"}
                  value="false"
                  label={path.label}
                  disabled={path_disabled}
                />
                <span
                  :if={path.disabled}
                  class="shrink-0 rounded-full bg-slate-200 px-2 py-0.5 text-[10px] font-bold uppercase tracking-wide text-slate-600"
                >
                  Already explored
                </span>
              </div>
              <p class={[
                "mt-3 font-serif text-base font-semibold leading-5",
                if(path_disabled, do: "text-slate-500", else: "text-slate-950")
              ]}>
                {path.question}
              </p>
              <p class={[
                "mt-1.5 text-xs leading-5",
                if(path_disabled, do: "text-slate-500", else: "text-slate-600")
              ]}>
                {path.reason}
              </p>
            </div>
          <% end %>

          <button
            id="guided-plan-path-submit"
            type="submit"
            disabled={!@can_edit || Enum.all?(@guided_paths, & &1.disabled)}
            class="inline-flex w-full items-center justify-center gap-2 rounded-xl bg-slate-950 px-4 py-2.5 text-sm font-semibold text-white shadow-sm transition hover:bg-slate-800 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-slate-400 focus-visible:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50"
          >
            Explore selected paths <.icon name="hero-arrow-right" class="h-4 w-4" />
          </button>
        </.form>
      </section>
    </div>
    """
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="h-full min-h-0">
      <div
        id={"node-menu-" <> @node_id}
        class="relative flex h-full min-h-0 flex-col"
        phx-hook={unless GraphHelpers.origin_branching_disabled?(@node), do: "TextSelectionHook"}
        data-node-id={@node.id}
        data-mudg-id={@graph_id}
        data-streaming={to_string(@streaming)}
        style="height: 100%; padding-bottom: env(safe-area-inset-bottom);"
      >
        <%= if @node.id == "start" do %>
          <.live_component module={DialecticWeb.StartTutorialComp} id="start-tutorial" />
        <% else %>
          <%!-- Thread View (Ancestor Chain) — hidden for now, revisit when full breadcrumb is implemented --%>

          <div
            class={[
              "min-h-0 flex-1 overflow-y-auto scroll-smooth px-3 pb-12 pt-3 sm:px-5 lg:px-6",
              String.length(@node.content) == 0 && "hidden"
            ]}
            id={"tt-node-" <> @node.id}
          >
            <div
              class="summary-content modal-responsive mx-auto w-full max-w-3xl"
              id={"tt-summary-content-" <> @node.id}
            >
              <div id={"node-content-#{@node.id}"}>
                <div id={"node-content-inner-#{@node.id}"}>
                  <% origin_meta? =
                    GraphHelpers.origin_branching_disabled?(@node) && is_map(@graph_struct) %>
                  <header
                    id={"node-title-header-#{@node.id}"}
                    class={[
                      "relative",
                      if(origin_meta?,
                        do: "mb-5 rounded-xl bg-slate-950 px-4 py-4 shadow-sm",
                        else:
                          "mb-6 rounded-xl border border-slate-200 bg-slate-50/90 px-4 py-3.5 shadow-sm"
                      )
                    ]}
                  >
                    <div class="min-w-0">
                      <p
                        id={"node-title-type-#{@node.id}"}
                        class={[
                          "mb-1.5 pr-10 text-[11px] font-semibold uppercase tracking-[0.16em]",
                          if(origin_meta?, do: "text-teal-200", else: "text-teal-700")
                        ]}
                      >
                        {if(origin_meta?,
                          do: "Starting question",
                          else: DialecticWeb.ColUtils.node_type_label(@node.class)
                        )}
                      </p>
                      <h2 class={[
                        "reader-heading text-balance font-semibold leading-[1.15] tracking-tight",
                        if(origin_meta?, do: "text-white", else: "text-slate-950"),
                        node_title_size_class(@node)
                      ]}>
                        <span
                          phx-hook="Markdown"
                          id={"markdown-title-#{@node.id}"}
                          data-md={@node.content || ""}
                          data-title-only="true"
                        ></span>
                      </h2>
                    </div>
                    <span class={[
                      "absolute right-3 top-2.5 flex items-center gap-2"
                    ]}>
                      <% noted? =
                        Enum.any?(Map.get(@node || %{}, :noted_by, []), fn u -> u == @user end) %>
                      <button
                        id={"graph-bookmark-node-#{@node.id}"}
                        type="button"
                        class={[
                          "inline-flex h-8 w-8 flex-none items-center justify-center rounded-full border transition-all",
                          if(noted?,
                            do: "border-amber-300 bg-amber-100 text-amber-800 hover:bg-amber-200",
                            else:
                              if(origin_meta?,
                                do:
                                  "border-white/20 bg-white/10 text-slate-300 hover:border-amber-300 hover:bg-amber-50 hover:text-amber-800",
                                else:
                                  "border-slate-200 bg-white text-slate-500 hover:border-amber-300 hover:bg-amber-50 hover:text-amber-800"
                              )
                          )
                        ]}
                        phx-click={if noted?, do: "unnote", else: "note"}
                        phx-value-node={@node.id}
                        aria-label={if(noted?, do: "Remove bookmark", else: "Bookmark this node")}
                        aria-pressed={to_string(noted?)}
                        title={if(noted?, do: "Remove bookmark", else: "Bookmark this node")}
                      >
                        <.icon
                          name={if(noted?, do: "hero-bookmark-solid", else: "hero-bookmark")}
                          class="h-4 w-4"
                        />
                      </button>
                    </span>
                  </header>
                  <article
                    class="reader-prose prose prose-slate max-w-none w-full prose-headings:font-serif prose-headings:tracking-tight prose-a:break-words"
                    data-role="node-content"
                  >
                    <%!-- Client-side Markdown rendering via Markdown hook --%>
                    <div
                      :if={origin_meta?}
                      id={"origin-intro-subheading-#{@node.id}"}
                      class="not-prose mb-5 rounded-xl border border-slate-200 bg-slate-50/80 px-4 py-3.5"
                    >
                      <p class="text-[11px] font-semibold uppercase tracking-[0.16em] text-teal-700">
                        About this grid
                      </p>
                      <p class="mt-1.5 text-[15px] leading-6 text-slate-700">
                        {graph_preview(@graph_struct)}
                      </p>

                      <div class="mt-3 flex flex-wrap gap-2">
                        <%= for tag <- graph_tags(@graph_struct) do %>
                          <span class={[
                            "inline-flex items-center rounded-md px-2.5 py-1 text-xs font-semibold ring-1 ring-inset",
                            GridCardComp.tag_pill_classes(tag)
                          ]}>
                            #{tag}
                          </span>
                        <% end %>
                      </div>
                    </div>

                    <div
                      class={[
                        "w-full pb-2",
                        if(origin_meta?, do: "px-1 sm:px-2", else: "px-4")
                      ]}
                      data-children={length(@node.children)}
                      id={"list-detector-" <> @node.id}
                    >
                      <div
                        :if={!GraphHelpers.origin_branching_disabled?(@node)}
                        id={"branch-from-text-hint-#{@node.id}"}
                        phx-hook="DismissibleHint"
                        data-dismiss-key="rg:dismissed:branch-from-text:v1"
                        class="not-prose relative mb-5 mt-3 overflow-hidden rounded-xl border border-teal-200/90 bg-gradient-to-r from-teal-50 via-white to-amber-50/80 p-3.5 pr-11 shadow-[0_14px_32px_-24px_rgba(15,118,110,0.9)] ring-1 ring-teal-100/70"
                        hidden
                      >
                        <div class="flex items-center gap-2.5">
                          <span class="inline-flex h-7 w-7 shrink-0 items-center justify-center rounded-lg bg-teal-700 text-white shadow-sm ring-1 ring-teal-800/10">
                            <.icon name="hero-cursor-arrow-rays" class="h-3.5 w-3.5" />
                          </span>
                          <p class="min-w-0 text-sm font-semibold leading-5 text-slate-800">
                            Select a phrase to ask about it.
                          </p>
                        </div>
                        <button
                          id={"branch-from-text-hint-dismiss-#{@node.id}"}
                          type="button"
                          data-dismiss-hint
                          class="absolute right-2.5 top-2.5 inline-flex h-7 w-7 items-center justify-center rounded-full text-slate-500 transition hover:bg-white/90 hover:text-slate-900 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-teal-600 focus-visible:ring-offset-2"
                          aria-label="Dismiss selection tip"
                          title="Dismiss tip"
                        >
                          <.icon name="hero-x-mark" class="h-4 w-4" />
                        </button>
                      </div>

                      <%= if interactive_learning_plan?(@node) do %>
                        <%= if @current_user do %>
                          <.learning_plan
                            node={@node}
                            guided_actions={@guided_actions}
                            guided_paths={@guided_paths}
                            guided_path_form={@guided_path_form}
                            max_explore_items={@max_explore_items}
                            can_edit={@can_edit}
                          />
                        <% else %>
                          <div
                            id={"guided-learning-login-#{@node.id}"}
                            class="not-prose rounded-2xl border border-indigo-200 bg-indigo-50/70 p-4"
                          >
                            <p class="text-sm font-semibold text-indigo-950">
                              Create an account to use this learning plan
                            </p>
                            <p class="mt-1 text-xs leading-5 text-indigo-800">
                              Registration is free and unlocks recommended branches and parallel exploration paths.
                            </p>
                            <button
                              id={"guided-learning-login-button-#{@node.id}"}
                              type="button"
                              phx-click="show_login_required"
                              class="mt-3 inline-flex items-center gap-1.5 rounded-full bg-indigo-700 px-3.5 py-2 text-xs font-semibold text-white shadow-sm transition hover:bg-indigo-600 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-indigo-500 focus-visible:ring-offset-2"
                            >
                              Create account or sign in
                              <.icon name="hero-arrow-right" class="h-3.5 w-3.5" />
                            </button>
                          </div>
                        <% end %>
                      <% else %>
                        <div
                          phx-hook="Markdown"
                          class="cursor-text selection:bg-amber-200/80 selection:text-slate-900"
                          id={"markdown-body-#{@node.id}"}
                          data-md={@node.content || ""}
                          data-grounding={DialecticWeb.MarkdownGrounding.encode(@node)}
                          data-body-only="true"
                          data-existing-follow-up-questions={existing_follow_up_questions_json(@node)}
                        >
                        </div>
                      <% end %>
                    </div>
                  </article>

                  <%= if GraphHelpers.origin_branching_disabled?(@node) do %>
                    <div
                      id={"origin-intro-#{@node.id}"}
                      class="mt-3 overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-[0_14px_32px_rgba(15,23,42,0.05)]"
                      data-external="true"
                      data-role="origin-intro"
                    >
                      <div class="border-b border-slate-200 bg-slate-50/80 px-4 py-3 sm:px-5">
                        <p class="text-[11px] font-semibold uppercase tracking-[0.18em] text-slate-500">
                          Start here
                        </p>
                        <h3 class="reader-heading mt-1 text-lg font-semibold leading-6 tracking-tight text-slate-950">
                          How to use the grid
                        </h3>
                      </div>

                      <div class="px-4 py-2.5 sm:px-5">
                        <.live_component
                          module={DialecticWeb.OriginOnboardingComp}
                          id={"origin-onboarding-#{@node.id}"}
                        />
                      </div>
                    </div>
                  <% else %>
                    <.live_component
                      module={DialecticWeb.ActionToolbarComp}
                      id={"action-toolbar-#{@node.id}"}
                      node={@node}
                      user={@user}
                      current_user={@current_user}
                      graph_id={@graph_id}
                      can_edit={@can_edit}
                      form={@form}
                      prompt_mode={@prompt_mode}
                      ask_question={@ask_question}
                    />
                  <% end %>
                </div>
              </div>
            </div>
          </div>

          <%= if String.length(@node.content) == 0 do %>
            <div class="node relative mb-2 overflow-hidden rounded-[1.75rem] border border-indigo-100 bg-gradient-to-br from-white via-indigo-50/70 to-sky-50/60 p-6 shadow-[0_24px_70px_rgba(79,70,229,0.14)] sm:p-8">
              <div class="pointer-events-none absolute -right-16 -top-16 h-44 w-44 rounded-full bg-indigo-200/40 blur-3xl">
              </div>
              <div class="pointer-events-none absolute -bottom-20 left-6 h-36 w-36 rounded-full bg-sky-200/30 blur-3xl">
              </div>

              <div class="relative space-y-6">
                <div class="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
                  <div class="flex items-start gap-3">
                    <span class="inline-flex h-11 w-11 shrink-0 items-center justify-center rounded-2xl bg-indigo-600 text-white shadow-lg shadow-indigo-200/80">
                      <.icon name="hero-sparkles" class="h-5 w-5" />
                    </span>
                    <div class="min-w-0">
                      <p class="text-sm font-semibold uppercase tracking-[0.18em] text-indigo-500">
                        Generating response
                      </p>
                      <h3
                        id={"generation-status-#{@node.id}"}
                        phx-hook="GenerationStatus"
                        phx-update="ignore"
                        data-response-level={Map.get(@node, :response_level, "")}
                        class="mt-1 text-lg font-semibold tracking-tight text-slate-950 sm:text-xl"
                      >
                        <span data-generation-status>Preparing response</span>
                      </h3>
                    </div>
                  </div>

                  <div class="flex items-center gap-1.5 rounded-full border border-indigo-100 bg-white/80 px-3 py-1.5 shadow-sm backdrop-blur">
                    <span class="text-xs font-medium text-indigo-700">Thinking</span>
                    <span class="flex gap-0.5">
                      <span class="h-1.5 w-1.5 rounded-full bg-indigo-500 animate-[typing_1.4s_ease-in-out_infinite]"></span>
                      <span class="h-1.5 w-1.5 rounded-full bg-indigo-500 animate-[typing_1.4s_ease-in-out_-0.16s_infinite]"></span>
                      <span class="h-1.5 w-1.5 rounded-full bg-indigo-500 animate-[typing_1.4s_ease-in-out_-0.32s_infinite]"></span>
                    </span>
                  </div>
                </div>

                <%!-- Animated shimmer skeleton lines --%>
                <div class="rounded-2xl border border-white/70 bg-white/65 p-4 shadow-inner shadow-indigo-100/40 backdrop-blur-sm">
                  <div class="space-y-4">
                    <div class="h-5 rounded-md w-3/4 bg-gradient-to-r from-indigo-100/70 via-white to-indigo-100/70 bg-[length:200%_100%] animate-[shimmer_1.5s_ease-in-out_infinite]">
                    </div>
                    <div class="space-y-2.5">
                      <div class="h-3.5 rounded-md w-full bg-gradient-to-r from-slate-100 via-white to-indigo-100/70 bg-[length:200%_100%] animate-[shimmer_1.5s_ease-in-out_0.1s_infinite]">
                      </div>
                      <div class="h-3.5 rounded-md w-5/6 bg-gradient-to-r from-slate-100 via-white to-indigo-100/70 bg-[length:200%_100%] animate-[shimmer_1.5s_ease-in-out_0.2s_infinite]">
                      </div>
                      <div class="h-3.5 rounded-md w-4/6 bg-gradient-to-r from-slate-100 via-white to-indigo-100/70 bg-[length:200%_100%] animate-[shimmer_1.5s_ease-in-out_0.3s_infinite]">
                      </div>
                    </div>
                    <div class="space-y-2.5 pt-2">
                      <div class="h-3.5 rounded-md w-full bg-gradient-to-r from-slate-100 via-white to-indigo-100/70 bg-[length:200%_100%] animate-[shimmer_1.5s_ease-in-out_0.4s_infinite]">
                      </div>
                      <div class="h-3.5 rounded-md w-2/3 bg-gradient-to-r from-slate-100 via-white to-indigo-100/70 bg-[length:200%_100%] animate-[shimmer_1.5s_ease-in-out_0.5s_infinite]">
                      </div>
                    </div>
                  </div>
                </div>

                <div
                  :if={@can_edit && show_regenerate_cta?(@node)}
                  class="thinking-regenerate-cta flex flex-col gap-3 rounded-2xl border border-indigo-200 bg-white/90 p-4 shadow-lg shadow-indigo-100/70 backdrop-blur sm:flex-row sm:items-center sm:justify-between"
                >
                  <div class="min-w-0">
                    <p class="text-sm font-semibold text-slate-900">Taking longer than expected?</p>
                    <p class="mt-0.5 text-sm text-slate-600">
                      You can safely replace this placeholder and try generating it again.
                    </p>
                  </div>

                  <button
                    id={"regenerate-thinking-node-#{@node.id}"}
                    type="button"
                    class="inline-flex shrink-0 items-center justify-center gap-2 rounded-xl bg-indigo-600 px-4 py-2.5 text-sm font-semibold text-white shadow-lg shadow-indigo-200/80 transition hover:bg-indigo-700 hover:shadow-indigo-300/80 focus-visible:outline-none focus-visible:ring-4 focus-visible:ring-indigo-200"
                    phx-click="node_regenerate"
                    phx-value-id={@node.id}
                    data-confirm="Try generating this node again? The stuck placeholder will be replaced."
                    title="Regenerate this stuck node"
                  >
                    <.icon name="hero-arrow-path" class="h-4 w-4" />
                    <span>Regenerate</span>
                  </button>
                </div>
              </div>
            </div>
          <% end %>
        <% end %>
      </div>
    </div>
    """
  end

  defp graph_tags(%{} = graph) do
    graph
    |> Map.get(:tags, [])
    |> case do
      tags when is_list(tags) ->
        tags
        |> Enum.filter(&(is_binary(&1) and String.trim(&1) != ""))
        |> Enum.take(4)

      _other ->
        []
    end
  end

  defp graph_tags(_graph), do: []

  defp graph_preview(%{} = graph), do: GridCardComp.preview_sentence(graph)

  defp graph_preview(_graph), do: "A connected grid of ideas."
end
