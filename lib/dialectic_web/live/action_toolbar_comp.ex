defmodule DialecticWeb.ActionToolbarComp do
  use DialecticWeb, :live_component

  alias DialecticWeb.ColUtils
  alias DialecticWeb.Utils.UserUtils

  @moduledoc """
  Node-level action toolbar for graph operations.

  ## Required Assigns
  - `:node` - The current node being operated on
  - `:user` - The user ID (for ownership checks)
  - `:current_user` - The current user struct
  - `:graph_id` - The graph ID
  - `:can_edit` - Boolean indicating if editing is allowed
  """

  defp delete_info(assigns) do
    node = assigns[:node]
    can_edit = assigns[:can_edit]
    current_user = assigns[:current_user]
    user = assigns[:user]

    children_list = (node && (node.children || [])) || []

    live_children =
      Enum.filter(children_list, fn ch -> not Map.get(ch, :deleted, false) end)

    no_live_children? = length(live_children) == 0

    owner? = UserUtils.owner?(node, %{current_user: current_user, user: user})

    locked? = can_edit == false
    deletable = owner? && no_live_children? && !locked?

    live_children_count = length(live_children)

    live_child_ids =
      live_children
      |> Enum.map(fn ch -> to_string(Map.get(ch, :id, "")) end)
      |> Enum.reject(&(&1 == ""))
      |> Enum.join(", ")

    delete_title =
      cond do
        deletable ->
          "Delete this node"

        locked? ->
          "Cannot delete: graph is locked"

        not owner? ->
          base =
            "Cannot delete: you are not the author"

          if String.trim(to_string((node && Map.get(node, :user)) || "")) == "" do
            base <> " [blank owner assumed current user]"
          else
            base
          end

        not no_live_children? ->
          base =
            "Cannot delete: this node has #{live_children_count} child" <>
              if live_children_count == 1, do: "", else: "ren"

          if live_child_ids != "" do
            base <> " (child IDs: " <> live_child_ids <> ")"
          else
            base
          end

        true ->
          "Cannot delete"
      end

    %{
      deletable: deletable,
      title: delete_title
    }
  end

  defp delete_button_class(deletable) do
    [
      "inline-flex shrink-0 items-center justify-center gap-2 self-start whitespace-nowrap rounded-xl border px-3 py-2 text-sm font-medium transition sm:self-center",
      if(deletable,
        do: "border-rose-200 bg-rose-50 text-rose-700 hover:border-rose-300 hover:bg-rose-100",
        else: "border-slate-200 bg-slate-100 text-slate-400 cursor-not-allowed"
      )
    ]
  end

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:advanced_tools_open, fn -> false end)}
  end

  @impl true
  def handle_event("toggle_advanced_tools", _, socket) do
    {:noreply, assign(socket, :advanced_tools_open, !socket.assigns.advanced_tools_open)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div
      class="mt-3 rounded-[1.7rem] border border-slate-200 bg-white p-4 shadow-[0_18px_40px_rgba(15,23,42,0.06)] sm:mt-4 sm:p-5"
      data-external="true"
      data-role="action-toolbar"
    >
      <% info = delete_info(assigns) %>

      <div class="flex flex-col gap-5">
        <div class="flex flex-col gap-3 border-b border-slate-200 pb-4 sm:flex-row sm:items-start sm:justify-between">
          <div class="space-y-2">
            <p class="text-[11px] font-semibold uppercase tracking-[0.18em] text-slate-500">
              Keep Exploring
            </p>
          </div>

          <div :if={@can_edit == false} class="sm:pt-1">
            <span
              class="inline-flex items-center gap-1.5 rounded-full border border-amber-200 bg-amber-50 px-2.5 py-1 text-xs font-semibold text-amber-700"
              title="Graph is locked; editing is disabled"
            >
              <.icon name="hero-lock-closed" class="h-3.5 w-3.5" />
              <span>Graph locked</span>
            </span>
          </div>
        </div>

        <div class="grid gap-2.5">
          <button
            type="button"
            class="group flex items-start gap-3 rounded-[1.2rem] border border-slate-200 bg-slate-50/80 px-4 py-3.5 text-left transition hover:border-emerald-200 hover:bg-white hover:shadow-sm active:scale-[0.99] focus-visible:outline-none focus-visible:ring-4 focus-visible:ring-emerald-100 disabled:cursor-not-allowed disabled:opacity-50"
            phx-click="node_branch"
            phx-value-id={@node && @node.id}
            disabled={is_nil(@graph_id)}
            title="Create supporting and opposing branches from this node"
          >
            <span class="inline-flex items-center justify-center rounded-xl bg-emerald-100 p-2.5 text-emerald-700">
              <.icon name="hero-scale" class="h-5 w-5" />
            </span>
            <span class="min-w-0 flex-1 space-y-1">
              <span class="block text-sm font-semibold text-slate-900">Test it with Pro / Con</span>
              <span class="block text-sm leading-5 text-slate-600">
                Generate the strongest case for it and against it.
              </span>
            </span>
            <span class="mt-1 inline-flex items-center gap-1 text-xs font-semibold uppercase tracking-[0.14em] text-emerald-700">
              <span>Explore</span>
              <.icon
                name="hero-arrow-right"
                class="h-4 w-4 transition-transform group-hover:translate-x-0.5"
              />
            </span>
          </button>

          <button
            type="button"
            class="group flex items-start gap-3 rounded-[1.2rem] border border-slate-200 bg-slate-50/80 px-4 py-3.5 text-left transition hover:border-violet-200 hover:bg-white hover:shadow-sm active:scale-[0.99] focus-visible:outline-none focus-visible:ring-4 focus-visible:ring-violet-100 disabled:cursor-not-allowed disabled:opacity-50"
            phx-click={
              Phoenix.LiveView.JS.dispatch("toggle-panel",
                to: "#graph-layout",
                detail: %{id: "combine-drawer"}
              )
              |> Phoenix.LiveView.JS.push("node_combine")
            }
            phx-value-id={@node && @node.id}
            disabled={is_nil(@graph_id)}
            data-panel-toggle="combine-drawer"
            aria-label="Blend this node with another"
            title="Blend this node with another"
          >
            <span class="inline-flex items-center justify-center rounded-xl bg-violet-100 p-2.5 text-violet-700">
              <.icon name="hero-arrows-pointing-in" class="h-5 w-5" />
            </span>
            <span class="min-w-0 flex-1 space-y-1">
              <span class="block text-sm font-semibold text-slate-900">Blend with another node</span>
              <span class="block text-sm leading-5 text-slate-600">
                Combine this point with another and see what new idea emerges.
              </span>
            </span>
            <span class="mt-1 inline-flex items-center gap-1 text-xs font-semibold uppercase tracking-[0.14em] text-violet-700">
              <span>Explore</span>
              <.icon
                name="hero-arrow-right"
                class="h-4 w-4 transition-transform group-hover:translate-x-0.5"
              />
            </span>
          </button>

          <button
            type="button"
            class="group flex items-start gap-3 rounded-[1.2rem] border border-slate-200 bg-slate-50/80 px-4 py-3.5 text-left transition hover:border-orange-200 hover:bg-white hover:shadow-sm active:scale-[0.99] focus-visible:outline-none focus-visible:ring-4 focus-visible:ring-orange-100 disabled:cursor-not-allowed disabled:opacity-50"
            phx-click="node_related_ideas"
            phx-value-id={@node && @node.id}
            disabled={is_nil(@graph_id)}
            title="Find related ideas"
            data-action="related-ideas"
          >
            <span class="inline-flex items-center justify-center rounded-xl bg-orange-100 p-2.5 text-orange-700">
              <.icon name="hero-light-bulb" class="h-5 w-5" />
            </span>
            <span class="min-w-0 flex-1 space-y-1">
              <span class="block text-sm font-semibold text-slate-900">Find related ideas</span>
              <span class="block text-sm leading-5 text-slate-600">
                Pull in nearby ideas, comparisons, and useful directions to explore next.
              </span>
            </span>
            <span class="mt-1 inline-flex items-center gap-1 text-xs font-semibold uppercase tracking-[0.14em] text-orange-700">
              <span>Explore</span>
              <.icon
                name="hero-arrow-right"
                class="h-4 w-4 transition-transform group-hover:translate-x-0.5"
              />
            </span>
          </button>
        </div>

        <%!-- Advanced Critical Thinking Tools Section --%>
        <div class="border-t border-slate-200/80 pt-4">
          <button
            type="button"
            class="w-full flex items-center justify-between gap-2 rounded-lg px-3 py-2 text-left transition hover:bg-slate-50"
            phx-click="toggle_advanced_tools"
            phx-target={@myself}
          >
            <div>
              <p class="text-sm font-semibold text-slate-900">Advanced Critical Thinking Tools</p>
              <p class="mt-0.5 text-xs text-slate-500">
                A focused set of reasoning moves for stress-testing claims and sharpening understanding.
              </p>
            </div>
            <.icon
              name="hero-chevron-down"
              class={
                if @advanced_tools_open,
                  do: "h-5 w-5 text-slate-400 transition-transform rotate-180",
                  else: "h-5 w-5 text-slate-400 transition-transform"
              }
            />
          </button>

          <div class={["mt-3 space-y-4", !@advanced_tools_open && "hidden"]}>
            <%!-- Core Analysis --%>
            <div>
              <h4 class="text-xs font-semibold uppercase tracking-wider text-slate-500 mb-2 px-1">
                Core Analysis
              </h4>
              <div class="grid gap-2 sm:grid-cols-2 lg:grid-cols-3">
                <%!-- Steel Man - First in list --%>
                <button
                  type="button"
                  class={[
                    "group flex flex-col items-start gap-2.5 rounded-[1.1rem] px-3.5 py-3 text-left shadow-sm transition hover:-translate-y-0.5 hover:shadow-md active:scale-[0.99] focus-visible:outline-none disabled:cursor-not-allowed disabled:opacity-50",
                    ColUtils.advanced_tool_surface_class("steel_man")
                  ]}
                  phx-click="node_steel_man"
                  phx-value-id={@node && @node.id}
                  disabled={is_nil(@graph_id)}
                  title="Steel Man: Build the strongest, most charitable version of this argument — the opposite of a straw man. Example: If someone says 'We should ban cars', the steel man would be 'In dense urban areas, reducing car dependency through better public transit and walkable design could improve health, reduce emissions, and create more livable communities.'"
                >
                  <span class={[
                    "inline-flex items-center justify-center rounded-xl p-2 shadow-sm",
                    ColUtils.advanced_tool_icon_class("steel_man")
                  ]}>
                    <.icon name="hero-star" class="h-4 w-4" />
                  </span>
                  <span class="space-y-0.5">
                    <span class="block text-xs font-semibold text-slate-900">Steel Man</span>
                    <span class="block text-xs leading-tight text-slate-600">
                      Strongest argument
                    </span>
                  </span>
                </button>

                <button
                  type="button"
                  class={[
                    "group flex flex-col items-start gap-2.5 rounded-[1.1rem] px-3.5 py-3 text-left shadow-sm transition hover:-translate-y-0.5 hover:shadow-md active:scale-[0.99] focus-visible:outline-none disabled:cursor-not-allowed disabled:opacity-50",
                    ColUtils.advanced_tool_surface_class("assumptions")
                  ]}
                  phx-click="node_assumptions"
                  phx-value-id={@node && @node.id}
                  disabled={is_nil(@graph_id)}
                  title="Assumptions: Reveal what must be true for this claim to work. Example: 'Remote work is better' assumes people have suitable home spaces, reliable internet, and self-discipline."
                >
                  <span class={[
                    "inline-flex items-center justify-center rounded-xl p-2 shadow-sm",
                    ColUtils.advanced_tool_icon_class("assumptions")
                  ]}>
                    <.icon name="hero-cube-transparent" class="h-4 w-4" />
                  </span>
                  <span class="space-y-0.5">
                    <span class="block text-xs font-semibold text-slate-900">Assumptions</span>
                    <span class="block text-xs leading-tight text-slate-600">
                      What has to be true?
                    </span>
                  </span>
                </button>

                <button
                  type="button"
                  class={[
                    "group flex flex-col items-start gap-2.5 rounded-[1.1rem] px-3.5 py-3 text-left shadow-sm transition hover:-translate-y-0.5 hover:shadow-md active:scale-[0.99] focus-visible:outline-none disabled:cursor-not-allowed disabled:opacity-50",
                    ColUtils.advanced_tool_surface_class("counterexample")
                  ]}
                  phx-click="node_counterexample"
                  phx-value-id={@node && @node.id}
                  disabled={is_nil(@graph_id)}
                  title="Test: Find counterexamples that challenge this claim. Example: If someone claims 'All successful people wake up early', counterexamples include successful artists, programmers, and entrepreneurs who are night owls."
                >
                  <span class={[
                    "inline-flex items-center justify-center rounded-xl p-2 shadow-sm",
                    ColUtils.advanced_tool_icon_class("counterexample")
                  ]}>
                    <.icon name="hero-x-mark" class="h-4 w-4" />
                  </span>
                  <span class="space-y-0.5">
                    <span class="block text-xs font-semibold text-slate-900">Test</span>
                    <span class="block text-xs leading-tight text-slate-600">
                      Is that always true?
                    </span>
                  </span>
                </button>
              </div>
            </div>

            <%!-- Critical Evaluation --%>
            <div>
              <h4 class="text-xs font-semibold uppercase tracking-wider text-slate-500 mb-2 px-1">
                Critical Evaluation
              </h4>
              <div class="grid gap-2 sm:grid-cols-2 lg:grid-cols-3">
                <button
                  type="button"
                  class={[
                    "group flex flex-col items-start gap-2.5 rounded-[1.1rem] px-3.5 py-3 text-left shadow-sm transition hover:-translate-y-0.5 hover:shadow-md active:scale-[0.99] focus-visible:outline-none disabled:cursor-not-allowed disabled:opacity-50",
                    ColUtils.advanced_tool_surface_class("says_who")
                  ]}
                  phx-click="node_says_who"
                  phx-value-id={@node && @node.id}
                  disabled={is_nil(@graph_id)}
                  title="Source Check: Question the authority and evidence behind claims. Example: 'Studies show X' — which studies? Who funded them? What was the sample size? Are there conflicting studies?"
                >
                  <span class={[
                    "inline-flex items-center justify-center rounded-xl p-2 shadow-sm",
                    ColUtils.advanced_tool_icon_class("says_who")
                  ]}>
                    <.icon name="hero-user" class="h-4 w-4" />
                  </span>
                  <span class="space-y-0.5">
                    <span class="block text-xs font-semibold text-slate-900">Source Check</span>
                    <span class="block text-xs leading-tight text-slate-600">Says who?</span>
                  </span>
                </button>

                <button
                  type="button"
                  class={[
                    "group flex flex-col items-start gap-2.5 rounded-[1.1rem] px-3.5 py-3 text-left shadow-sm transition hover:-translate-y-0.5 hover:shadow-md active:scale-[0.99] focus-visible:outline-none disabled:cursor-not-allowed disabled:opacity-50",
                    ColUtils.advanced_tool_surface_class("blind_spots")
                  ]}
                  phx-click="node_blind_spots"
                  phx-value-id={@node && @node.id}
                  disabled={is_nil(@graph_id)}
                  title="Blind Spots: Identify perspectives, factors, or constraints being overlooked. Example: A tech solution might ignore users without internet access or digital literacy."
                >
                  <span class={[
                    "inline-flex items-center justify-center rounded-xl p-2 shadow-sm",
                    ColUtils.advanced_tool_icon_class("blind_spots")
                  ]}>
                    <.icon name="hero-eye-slash" class="h-4 w-4" />
                  </span>
                  <span class="space-y-0.5">
                    <span class="block text-xs font-semibold text-slate-900">Blind Spots</span>
                    <span class="block text-xs leading-tight text-slate-600">
                      What are we missing?
                    </span>
                  </span>
                </button>

                <button
                  type="button"
                  class={[
                    "group flex flex-col items-start gap-2.5 rounded-[1.1rem] px-3.5 py-3 text-left shadow-sm transition hover:-translate-y-0.5 hover:shadow-md active:scale-[0.99] focus-visible:outline-none disabled:cursor-not-allowed disabled:opacity-50",
                    ColUtils.advanced_tool_surface_class("who_disagrees")
                  ]}
                  phx-click="node_who_disagrees"
                  phx-value-id={@node && @node.id}
                  disabled={is_nil(@graph_id)}
                  title="Who Disagrees: Explore different perspectives and opposing viewpoints. Example: For 'Everyone should go to college', consider vocational experts, entrepreneurs, and trades professionals."
                >
                  <span class={[
                    "inline-flex items-center justify-center rounded-xl p-2 shadow-sm",
                    ColUtils.advanced_tool_icon_class("who_disagrees")
                  ]}>
                    <.icon name="hero-users" class="h-4 w-4" />
                  </span>
                  <span class="space-y-0.5">
                    <span class="block text-xs font-semibold text-slate-900">Who Disagrees</span>
                    <span class="block text-xs leading-tight text-slate-600">
                      Other perspectives?
                    </span>
                  </span>
                </button>
              </div>
            </div>

            <%!-- Consequences & Counterfactuals --%>
            <div>
              <h4 class="text-xs font-semibold uppercase tracking-wider text-slate-500 mb-2 px-1">
                Consequences & Counterfactuals
              </h4>
              <div class="grid gap-2 sm:grid-cols-2 lg:grid-cols-3">
                <button
                  type="button"
                  class={[
                    "group flex flex-col items-start gap-2.5 rounded-[1.1rem] px-3.5 py-3 text-left shadow-sm transition hover:-translate-y-0.5 hover:shadow-md active:scale-[0.99] focus-visible:outline-none disabled:cursor-not-allowed disabled:opacity-50",
                    ColUtils.advanced_tool_surface_class("implications")
                  ]}
                  phx-click="node_implications"
                  phx-value-id={@node && @node.id}
                  disabled={is_nil(@graph_id)}
                  title="Implications: What would happen if this were true? Example: 'Universal basic income' implies changes to work incentives, tax systems, inflation, and social safety nets."
                >
                  <span class={[
                    "inline-flex items-center justify-center rounded-xl p-2 shadow-sm",
                    ColUtils.advanced_tool_icon_class("implications")
                  ]}>
                    <.icon name="hero-arrow-trending-up" class="h-4 w-4" />
                  </span>
                  <span class="space-y-0.5">
                    <span class="block text-xs font-semibold text-slate-900">Implications</span>
                    <span class="block text-xs leading-tight text-slate-600">
                      If true, then what?
                    </span>
                  </span>
                </button>

                <button
                  type="button"
                  class={[
                    "group flex flex-col items-start gap-2.5 rounded-[1.1rem] px-3.5 py-3 text-left shadow-sm transition hover:-translate-y-0.5 hover:shadow-md active:scale-[0.99] focus-visible:outline-none disabled:cursor-not-allowed disabled:opacity-50",
                    ColUtils.advanced_tool_surface_class("what_if")
                  ]}
                  phx-click="node_what_if"
                  phx-value-id={@node && @node.id}
                  disabled={is_nil(@graph_id)}
                  title="What If: Explore hypothetical scenarios and alternative possibilities. Example: 'What if we had universal healthcare?' or 'What if fossil fuels ran out tomorrow?'"
                >
                  <span class={[
                    "inline-flex items-center justify-center rounded-xl p-2 shadow-sm",
                    ColUtils.advanced_tool_icon_class("what_if")
                  ]}>
                    <.icon name="hero-question-mark-circle" class="h-4 w-4" />
                  </span>
                  <span class="space-y-0.5">
                    <span class="block text-xs font-semibold text-slate-900">What If</span>
                    <span class="block text-xs leading-tight text-slate-600">
                      Hypothetical scenarios
                    </span>
                  </span>
                </button>
              </div>
            </div>

            <%!-- Conceptual Precision --%>
            <div>
              <h4 class="text-xs font-semibold uppercase tracking-wider text-slate-500 mb-2 px-1">
                Conceptual Precision
              </h4>
              <div class="grid gap-2 sm:grid-cols-2 lg:grid-cols-3">
                <button
                  type="button"
                  class={[
                    "group flex flex-col items-start gap-2.5 rounded-[1.1rem] px-3.5 py-3 text-left shadow-sm transition hover:-translate-y-0.5 hover:shadow-md active:scale-[0.99] focus-visible:outline-none disabled:cursor-not-allowed disabled:opacity-50",
                    ColUtils.advanced_tool_surface_class("clarify")
                  ]}
                  phx-click="node_clarify"
                  phx-value-id={@node && @node.id}
                  disabled={is_nil(@graph_id)}
                  title="Clarify Terms: Identify key terms, hidden ambiguity, conceptual boundaries, and what would count as evidence."
                >
                  <span class={[
                    "inline-flex items-center justify-center rounded-xl p-2 shadow-sm",
                    ColUtils.advanced_tool_icon_class("clarify")
                  ]}>
                    <.icon name="hero-light-bulb" class="h-4 w-4" />
                  </span>
                  <span class="space-y-0.5">
                    <span class="block text-xs font-semibold text-slate-900">Clarify Terms</span>
                    <span class="block text-xs leading-tight text-slate-600">
                      What do we mean?
                    </span>
                  </span>
                </button>

                <%!-- Deep Dive - Hidden for now --%>
                <%!--
                <button
                  type="button"
                  class="group flex flex-col items-start gap-2 rounded-lg border border-slate-200/80 bg-gradient-to-br from-white to-slate-50/50 px-3 py-2.5 text-left shadow-sm transition hover:-translate-y-0.5 hover:border-slate-300 hover:shadow-md disabled:cursor-not-allowed disabled:opacity-50"
                  phx-click="node_deepdive"
                  phx-value-id={@node && @node.id}
                  disabled={is_nil(@graph_id)}
                  title="Deep Dive: Explore the topic in greater depth with nuance, context, and detailed analysis."
                >
                  <span class="inline-flex items-center justify-center rounded-lg bg-slate-100 p-1.5 text-slate-700">
                    <.icon name="hero-magnifying-glass-plus" class="h-4 w-4" />
                  </span>
                  <span class="space-y-0.5">
                    <span class="block text-xs font-semibold text-slate-900">Deep Dive</span>
                    <span class="block text-xs leading-tight text-slate-600">
                      Go deeper
                    </span>
                  </span>
                </button>
                ---%>
              </div>
            </div>
          </div>
        </div>

        <div class="flex flex-col gap-3 border-t border-slate-200/80 pt-4 sm:flex-row sm:items-start sm:justify-between sm:gap-4">
          <div class="max-w-xl">
            <p class="mt-1 text-sm text-slate-500">
              Delete is only available to the author when nothing else in the grid depends on it.
            </p>
          </div>

          <button
            id={"delete-node-#{@graph_id}-#{@node && @node.id}"}
            type="button"
            disabled={is_nil(@graph_id)}
            phx-click={if info.deletable, do: "delete_node", else: nil}
            phx-value-node={@node && @node.id}
            data-confirm={
              if info.deletable, do: "Are you sure you want to delete this node?", else: nil
            }
            aria-disabled={not info.deletable}
            data-disabled={not info.deletable}
            class={delete_button_class(info.deletable)}
            title={info.title}
          >
            <.icon name="hero-trash" class="h-4 w-4" />
            <span>Delete node</span>
          </button>
        </div>
      </div>
    </div>
    """
  end
end
