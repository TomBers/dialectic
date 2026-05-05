defmodule DialecticWeb.ActionToolbarComp do
  use DialecticWeb, :live_component

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
      "inline-flex items-center justify-center gap-2 rounded-xl border px-3 py-2 text-sm font-medium transition",
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
      class="mt-6 rounded-[1.9rem] border border-slate-200/80 bg-gradient-to-br from-white via-sky-50/70 to-indigo-50/70 p-4 shadow-[0_18px_40px_rgba(15,23,42,0.06)] sm:mt-8 sm:p-5"
      data-external="true"
      data-role="action-toolbar"
    >
      <% info = delete_info(assigns) %>

      <div class="flex flex-col gap-5">
        <div class="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
          <div class="space-y-1">
            <p class="text-[11px] font-semibold uppercase tracking-[0.18em] text-sky-700">
              Keep Exploring
            </p>
            <div>
              <h4 class="text-base font-semibold tracking-tight text-slate-900 sm:text-lg">
                Where would you like to go next?
              </h4>
              <p class="mt-1 text-sm leading-6 text-slate-600">
                Choose one path to test the idea, connect it to something nearby, or open a fresh angle.
              </p>
            </div>
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

        <div class="grid gap-3 sm:grid-cols-3">
          <button
            type="button"
            class="group flex h-full flex-col items-start gap-3 rounded-[1.35rem] border border-emerald-200/80 bg-gradient-to-br from-white to-emerald-50/70 px-4 py-3.5 text-left shadow-sm transition hover:-translate-y-0.5 hover:border-emerald-300 hover:shadow-md disabled:cursor-not-allowed disabled:opacity-50"
            phx-click="node_branch"
            phx-value-id={@node && @node.id}
            disabled={is_nil(@graph_id)}
            title="Create supporting and opposing branches from this node"
          >
            <span class="inline-flex items-center justify-center rounded-xl bg-emerald-100 p-2.5 text-emerald-700 shadow-sm">
              <.icon name="hero-scale" class="h-5 w-5" />
            </span>
            <span class="space-y-1">
              <span class="block text-sm font-semibold text-slate-900">Pro | Con</span>
              <span class="block text-sm leading-5 text-slate-600">
                See the strongest case for it and against it.
              </span>
            </span>
          </button>

          <button
            type="button"
            class="group flex h-full flex-col items-start gap-3 rounded-[1.35rem] border border-violet-200/80 bg-gradient-to-br from-white to-violet-50/70 px-4 py-3.5 text-left shadow-sm transition hover:-translate-y-0.5 hover:border-violet-300 hover:shadow-md disabled:cursor-not-allowed disabled:opacity-50"
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
            <span class="inline-flex items-center justify-center rounded-xl bg-violet-100 p-2.5 text-violet-700 shadow-sm">
              <.icon name="hero-arrows-pointing-in" class="h-5 w-5" />
            </span>
            <span class="space-y-1">
              <span class="block text-sm font-semibold text-slate-900">Blend</span>
              <span class="block text-sm leading-5 text-slate-600">
                Bring this point together with another and see what emerges.
              </span>
            </span>
          </button>

          <button
            type="button"
            class="group flex h-full flex-col items-start gap-3 rounded-[1.35rem] border border-amber-200/80 bg-gradient-to-br from-white to-amber-50/70 px-4 py-3.5 text-left shadow-sm transition hover:-translate-y-0.5 hover:border-amber-300 hover:shadow-md disabled:cursor-not-allowed disabled:opacity-50"
            phx-click="node_related_ideas"
            phx-value-id={@node && @node.id}
            disabled={is_nil(@graph_id)}
            title="Find related ideas"
            data-action="related-ideas"
          >
            <span class="inline-flex items-center justify-center rounded-xl bg-amber-100 p-2.5 text-amber-700 shadow-sm">
              <.icon name="hero-light-bulb" class="h-5 w-5" />
            </span>
            <span class="space-y-1">
              <span class="block text-sm font-semibold text-slate-900">Related</span>
              <span class="block text-sm leading-5 text-slate-600">
                Pull in nearby ideas, comparisons, and useful directions to explore.
              </span>
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
                🎯 Try these to deepen your analysis — click to explore
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
                  class="group flex flex-col items-start gap-2 rounded-lg border border-yellow-200/80 bg-gradient-to-br from-white to-yellow-50/50 px-3 py-2.5 text-left shadow-sm transition hover:-translate-y-0.5 hover:border-yellow-300 hover:shadow-md disabled:cursor-not-allowed disabled:opacity-50"
                  phx-click="node_steel_man"
                  phx-value-id={@node && @node.id}
                  disabled={is_nil(@graph_id)}
                  title="Steel Man: Build the strongest, most charitable version of this argument — the opposite of a straw man. Example: If someone says 'We should ban cars', the steel man would be 'In dense urban areas, reducing car dependency through better public transit and walkable design could improve health, reduce emissions, and create more livable communities.'"
                >
                  <span class="inline-flex items-center justify-center rounded-lg bg-yellow-100 p-1.5 text-yellow-700">
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
                  class="group flex flex-col items-start gap-2 rounded-lg border border-amber-200/80 bg-gradient-to-br from-white to-amber-50/50 px-3 py-2.5 text-left shadow-sm transition hover:-translate-y-0.5 hover:border-amber-300 hover:shadow-md disabled:cursor-not-allowed disabled:opacity-50"
                  phx-click="node_assumptions"
                  phx-value-id={@node && @node.id}
                  disabled={is_nil(@graph_id)}
                  title="Assumptions: Reveal what must be true for this claim to work. Example: 'Remote work is better' assumes people have suitable home spaces, reliable internet, and self-discipline."
                >
                  <span class="inline-flex items-center justify-center rounded-lg bg-amber-100 p-1.5 text-amber-700">
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
                  class="group flex flex-col items-start gap-2 rounded-lg border border-red-200/80 bg-gradient-to-br from-white to-red-50/50 px-3 py-2.5 text-left shadow-sm transition hover:-translate-y-0.5 hover:border-red-300 hover:shadow-md disabled:cursor-not-allowed disabled:opacity-50"
                  phx-click="node_counterexample"
                  phx-value-id={@node && @node.id}
                  disabled={is_nil(@graph_id)}
                  title="Test: Find counterexamples that challenge this claim. Example: If someone claims 'All successful people wake up early', counterexamples include successful artists, programmers, and entrepreneurs who are night owls."
                >
                  <span class="inline-flex items-center justify-center rounded-lg bg-red-100 p-1.5 text-red-700">
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
                  class="group flex flex-col items-start gap-2 rounded-lg border border-sky-200/80 bg-gradient-to-br from-white to-sky-50/50 px-3 py-2.5 text-left shadow-sm transition hover:-translate-y-0.5 hover:border-sky-300 hover:shadow-md disabled:cursor-not-allowed disabled:opacity-50"
                  phx-click="node_says_who"
                  phx-value-id={@node && @node.id}
                  disabled={is_nil(@graph_id)}
                  title="Source: Question the authority and evidence behind claims. Example: 'Studies show X' — which studies? Who funded them? What was the sample size? Are there conflicting studies?"
                >
                  <span class="inline-flex items-center justify-center rounded-lg bg-sky-100 p-1.5 text-sky-700">
                    <.icon name="hero-user" class="h-4 w-4" />
                  </span>
                  <span class="space-y-0.5">
                    <span class="block text-xs font-semibold text-slate-900">Source</span>
                    <span class="block text-xs leading-tight text-slate-600">Says who?</span>
                  </span>
                </button>

                <button
                  type="button"
                  class="group flex flex-col items-start gap-2 rounded-lg border border-orange-200/80 bg-gradient-to-br from-white to-orange-50/50 px-3 py-2.5 text-left shadow-sm transition hover:-translate-y-0.5 hover:border-orange-300 hover:shadow-md disabled:cursor-not-allowed disabled:opacity-50"
                  phx-click="node_blind_spots"
                  phx-value-id={@node && @node.id}
                  disabled={is_nil(@graph_id)}
                  title="Blind Spots: Identify perspectives, factors, or constraints being overlooked. Example: A tech solution might ignore users without internet access or digital literacy."
                >
                  <span class="inline-flex items-center justify-center rounded-lg bg-orange-100 p-1.5 text-orange-700">
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
                  class="group flex flex-col items-start gap-2 rounded-lg border border-pink-200/80 bg-gradient-to-br from-white to-pink-50/50 px-3 py-2.5 text-left shadow-sm transition hover:-translate-y-0.5 hover:border-pink-300 hover:shadow-md disabled:cursor-not-allowed disabled:opacity-50"
                  phx-click="node_who_disagrees"
                  phx-value-id={@node && @node.id}
                  disabled={is_nil(@graph_id)}
                  title="Who Disagrees: Explore different perspectives and opposing viewpoints. Example: For 'Everyone should go to college', consider vocational experts, entrepreneurs, and trades professionals."
                >
                  <span class="inline-flex items-center justify-center rounded-lg bg-pink-100 p-1.5 text-pink-700">
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

            <%!-- Implications & Consequences --%>
            <div>
              <h4 class="text-xs font-semibold uppercase tracking-wider text-slate-500 mb-2 px-1">
                Implications & Consequences
              </h4>
              <div class="grid gap-2 sm:grid-cols-2 lg:grid-cols-3">
                <button
                  type="button"
                  class="group flex flex-col items-start gap-2 rounded-lg border border-green-200/80 bg-gradient-to-br from-white to-green-50/50 px-3 py-2.5 text-left shadow-sm transition hover:-translate-y-0.5 hover:border-green-300 hover:shadow-md disabled:cursor-not-allowed disabled:opacity-50"
                  phx-click="node_implications"
                  phx-value-id={@node && @node.id}
                  disabled={is_nil(@graph_id)}
                  title="Implications: What would happen if this were true? Example: 'Universal basic income' implies changes to work incentives, tax systems, inflation, and social safety nets."
                >
                  <span class="inline-flex items-center justify-center rounded-lg bg-green-100 p-1.5 text-green-700">
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
                  class="group flex flex-col items-start gap-2 rounded-lg border border-purple-200/80 bg-gradient-to-br from-white to-purple-50/50 px-3 py-2.5 text-left shadow-sm transition hover:-translate-y-0.5 hover:border-purple-300 hover:shadow-md disabled:cursor-not-allowed disabled:opacity-50"
                  phx-click="node_second_order"
                  phx-value-id={@node && @node.id}
                  disabled={is_nil(@graph_id)}
                  title="Second Order: Explore indirect consequences and ripple effects. Example: 'Free college tuition' leads to more graduates, which leads to credential inflation, changing job requirements, and shifts in what skills are valued."
                >
                  <span class="inline-flex items-center justify-center rounded-lg bg-purple-100 p-1.5 text-purple-700">
                    <.icon name="hero-arrow-path" class="h-4 w-4" />
                  </span>
                  <span class="space-y-0.5">
                    <span class="block text-xs font-semibold text-slate-900">Second Order</span>
                    <span class="block text-xs leading-tight text-slate-600">
                      Ripple effects?
                    </span>
                  </span>
                </button>

                <button
                  type="button"
                  class="group flex flex-col items-start gap-2 rounded-lg border border-teal-200/80 bg-gradient-to-br from-white to-teal-50/50 px-3 py-2.5 text-left shadow-sm transition hover:-translate-y-0.5 hover:border-teal-300 hover:shadow-md disabled:cursor-not-allowed disabled:opacity-50"
                  phx-click="node_what_if"
                  phx-value-id={@node && @node.id}
                  disabled={is_nil(@graph_id)}
                  title="What If: Explore hypothetical scenarios and alternative possibilities. Example: 'What if we had universal healthcare?' or 'What if fossil fuels ran out tomorrow?'"
                >
                  <span class="inline-flex items-center justify-center rounded-lg bg-teal-100 p-1.5 text-teal-700">
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

            <%!-- Understanding & Communication --%>
            <div>
              <h4 class="text-xs font-semibold uppercase tracking-wider text-slate-500 mb-2 px-1">
                Understanding & Communication
              </h4>
              <div class="grid gap-2 sm:grid-cols-2 lg:grid-cols-3">
                <button
                  type="button"
                  class="group flex flex-col items-start gap-2 rounded-lg border border-blue-200/80 bg-gradient-to-br from-white to-blue-50/50 px-3 py-2.5 text-left shadow-sm transition hover:-translate-y-0.5 hover:border-blue-300 hover:shadow-md disabled:cursor-not-allowed disabled:opacity-50"
                  phx-click="node_clarify"
                  phx-value-id={@node && @node.id}
                  disabled={is_nil(@graph_id)}
                  title="Clarify: Make complex ideas clearer with simpler language and concrete examples. Example: 'Quantum entanglement' becomes 'When two particles are linked so that measuring one instantly affects the other, no matter the distance.'"
                >
                  <span class="inline-flex items-center justify-center rounded-lg bg-blue-100 p-1.5 text-blue-700">
                    <.icon name="hero-light-bulb" class="h-4 w-4" />
                  </span>
                  <span class="space-y-0.5">
                    <span class="block text-xs font-semibold text-slate-900">Clarify</span>
                    <span class="block text-xs leading-tight text-slate-600">
                      Explain it simply
                    </span>
                  </span>
                </button>

                <button
                  type="button"
                  class="group flex flex-col items-start gap-2 rounded-lg border border-cyan-200/80 bg-gradient-to-br from-white to-cyan-50/50 px-3 py-2.5 text-left shadow-sm transition hover:-translate-y-0.5 hover:border-cyan-300 hover:shadow-md disabled:cursor-not-allowed disabled:opacity-50"
                  phx-click="node_simplify"
                  phx-value-id={@node && @node.id}
                  disabled={is_nil(@graph_id)}
                  title="Simplify: Break down complex ideas into plain language anyone can understand. Example: Turn technical jargon into everyday terms with concrete examples."
                >
                  <span class="inline-flex items-center justify-center rounded-lg bg-cyan-100 p-1.5 text-cyan-700">
                    <.icon name="hero-sparkles" class="h-4 w-4" />
                  </span>
                  <span class="space-y-0.5">
                    <span class="block text-xs font-semibold text-slate-900">Simplify</span>
                    <span class="block text-xs leading-tight text-slate-600">
                      Plain language
                    </span>
                  </span>
                </button>

                <button
                  type="button"
                  class="group flex flex-col items-start gap-2 rounded-lg border border-indigo-200/80 bg-gradient-to-br from-white to-indigo-50/50 px-3 py-2.5 text-left shadow-sm transition hover:-translate-y-0.5 hover:border-indigo-300 hover:shadow-md disabled:cursor-not-allowed disabled:opacity-50"
                  phx-click="node_analogy"
                  phx-value-id={@node && @node.id}
                  disabled={is_nil(@graph_id)}
                  title="Analogy: Understand ideas through comparison to familiar concepts. Example: 'Blockchain is like a public ledger where everyone has a copy and can verify entries.'"
                >
                  <span class="inline-flex items-center justify-center rounded-lg bg-indigo-100 p-1.5 text-indigo-700">
                    <.icon name="hero-arrows-right-left" class="h-4 w-4" />
                  </span>
                  <span class="space-y-0.5">
                    <span class="block text-xs font-semibold text-slate-900">Analogy</span>
                    <span class="block text-xs leading-tight text-slate-600">
                      Like what?
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

        <div class="flex flex-col gap-3 border-t border-slate-200/80 pt-4 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <p class="text-sm font-medium text-slate-900">Need to tidy this node?</p>
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
