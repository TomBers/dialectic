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
              <p class="mt-0.5 text-xs text-slate-500">Explore deeper inquiry moves</p>
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
            <%!-- Core Inquiry --%>
            <div>
              <p class="mb-2 text-[10px] font-semibold uppercase tracking-wider text-slate-500">
                Core Inquiry
              </p>
              <div class="grid gap-2 sm:grid-cols-2">
                <button
                  type="button"
                  class="group flex flex-col items-start gap-2 rounded-lg border border-teal-200/80 bg-gradient-to-br from-white to-teal-50/50 px-3 py-2.5 text-left shadow-sm transition hover:-translate-y-0.5 hover:border-teal-300 hover:shadow-md disabled:cursor-not-allowed disabled:opacity-50"
                  phx-click="node_clarify"
                  phx-value-id={@node && @node.id}
                  disabled={is_nil(@graph_id)}
                  title="What do you mean by…? — Conceptual clarification"
                >
                  <span class="inline-flex items-center justify-center rounded-lg bg-teal-100 p-1.5 text-teal-700">
                    <.icon name="hero-question-mark-circle" class="h-4 w-4" />
                  </span>
                  <span class="space-y-0.5">
                    <span class="block text-xs font-semibold text-slate-900">Clarify</span>
                    <span class="block text-xs leading-tight text-slate-600">
                      What do you mean by…?
                    </span>
                  </span>
                </button>

                <button
                  type="button"
                  class="group flex flex-col items-start gap-2 rounded-lg border border-amber-200/80 bg-gradient-to-br from-white to-amber-50/50 px-3 py-2.5 text-left shadow-sm transition hover:-translate-y-0.5 hover:border-amber-300 hover:shadow-md disabled:cursor-not-allowed disabled:opacity-50"
                  phx-click="node_assumptions"
                  phx-value-id={@node && @node.id}
                  disabled={is_nil(@graph_id)}
                  title="What has to be true? — Surface hidden assumptions"
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
                  title="Is that always true? — Find counterexamples"
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

                <button
                  type="button"
                  class="group flex flex-col items-start gap-2 rounded-lg border border-indigo-200/80 bg-gradient-to-br from-white to-indigo-50/50 px-3 py-2.5 text-left shadow-sm transition hover:-translate-y-0.5 hover:border-indigo-300 hover:shadow-md disabled:cursor-not-allowed disabled:opacity-50"
                  phx-click="node_implications"
                  phx-value-id={@node && @node.id}
                  disabled={is_nil(@graph_id)}
                  title="So what? — Trace the consequences"
                >
                  <span class="inline-flex items-center justify-center rounded-lg bg-indigo-100 p-1.5 text-indigo-700">
                    <.icon name="hero-arrow-right" class="h-4 w-4" />
                  </span>
                  <span class="space-y-0.5">
                    <span class="block text-xs font-semibold text-slate-900">Implications</span>
                    <span class="block text-xs leading-tight text-slate-600">So what?</span>
                  </span>
                </button>
              </div>

              <button
                type="button"
                class="mt-2 w-full group flex flex-col items-start gap-2 rounded-lg border border-purple-200/80 bg-gradient-to-br from-white to-purple-50/50 px-3 py-2.5 text-left shadow-sm transition hover:-translate-y-0.5 hover:border-purple-300 hover:shadow-md disabled:cursor-not-allowed disabled:opacity-50"
                phx-click="node_blind_spots"
                phx-value-id={@node && @node.id}
                disabled={is_nil(@graph_id)}
                title="What's missing? — Detect blind spots"
              >
                <span class="inline-flex items-center justify-center rounded-lg bg-purple-100 p-1.5 text-purple-700">
                  <.icon name="hero-eye-slash" class="h-4 w-4" />
                </span>
                <span class="space-y-0.5">
                  <span class="block text-xs font-semibold text-slate-900">Blind Spots</span>
                  <span class="block text-xs leading-tight text-slate-600">
                    What's missing from this view?
                  </span>
                </span>
              </button>
            </div>

            <%!-- Context & Expansion --%>
            <div>
              <p class="mb-2 text-[10px] font-semibold uppercase tracking-wider text-slate-500">
                Context & Expansion
              </p>
              <div class="grid gap-2 sm:grid-cols-2">
                <button
                  type="button"
                  class="group flex flex-col items-start gap-2 rounded-lg border border-sky-200/80 bg-gradient-to-br from-white to-sky-50/50 px-3 py-2.5 text-left shadow-sm transition hover:-translate-y-0.5 hover:border-sky-300 hover:shadow-md disabled:cursor-not-allowed disabled:opacity-50"
                  phx-click="node_says_who"
                  phx-value-id={@node && @node.id}
                  disabled={is_nil(@graph_id)}
                  title="Says who? — Check sources and authority"
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
                  class="group flex flex-col items-start gap-2 rounded-lg border border-rose-200/80 bg-gradient-to-br from-white to-rose-50/50 px-3 py-2.5 text-left shadow-sm transition hover:-translate-y-0.5 hover:border-rose-300 hover:shadow-md disabled:cursor-not-allowed disabled:opacity-50"
                  phx-click="node_who_disagrees"
                  phx-value-id={@node && @node.id}
                  disabled={is_nil(@graph_id)}
                  title="Who disagrees? — Map the opposition"
                >
                  <span class="inline-flex items-center justify-center rounded-lg bg-rose-100 p-1.5 text-rose-700">
                    <.icon name="hero-users" class="h-4 w-4" />
                  </span>
                  <span class="space-y-0.5">
                    <span class="block text-xs font-semibold text-slate-900">Dissent</span>
                    <span class="block text-xs leading-tight text-slate-600">
                      Who disagrees?
                    </span>
                  </span>
                </button>

                <button
                  type="button"
                  class="group flex flex-col items-start gap-2 rounded-lg border border-emerald-200/80 bg-gradient-to-br from-white to-emerald-50/50 px-3 py-2.5 text-left shadow-sm transition hover:-translate-y-0.5 hover:border-emerald-300 hover:shadow-md disabled:cursor-not-allowed disabled:opacity-50"
                  phx-click="node_analogy"
                  phx-value-id={@node && @node.id}
                  disabled={is_nil(@graph_id)}
                  title="What is this like? — Find analogies"
                >
                  <span class="inline-flex items-center justify-center rounded-lg bg-emerald-100 p-1.5 text-emerald-700">
                    <.icon name="hero-link" class="h-4 w-4" />
                  </span>
                  <span class="space-y-0.5">
                    <span class="block text-xs font-semibold text-slate-900">Analogy</span>
                    <span class="block text-xs leading-tight text-slate-600">
                      What is this like?
                    </span>
                  </span>
                </button>

                <button
                  type="button"
                  class="group flex flex-col items-start gap-2 rounded-lg border border-yellow-200/80 bg-gradient-to-br from-white to-yellow-50/50 px-3 py-2.5 text-left shadow-sm transition hover:-translate-y-0.5 hover:border-yellow-300 hover:shadow-md disabled:cursor-not-allowed disabled:opacity-50"
                  phx-click="node_steel_man"
                  phx-value-id={@node && @node.id}
                  disabled={is_nil(@graph_id)}
                  title="Steel man — Strongest version of the argument"
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
              </div>

              <button
                type="button"
                class="mt-2 w-full group flex flex-col items-start gap-2 rounded-lg border border-fuchsia-200/80 bg-gradient-to-br from-white to-fuchsia-50/50 px-3 py-2.5 text-left shadow-sm transition hover:-translate-y-0.5 hover:border-fuchsia-300 hover:shadow-md disabled:cursor-not-allowed disabled:opacity-50"
                phx-click="node_what_if"
                phx-value-id={@node && @node.id}
                disabled={is_nil(@graph_id)}
                title="What if we change X? — Explore counterfactuals"
              >
                <span class="inline-flex items-center justify-center rounded-lg bg-fuchsia-100 p-1.5 text-fuchsia-700">
                  <.icon name="hero-beaker" class="h-4 w-4" />
                </span>
                <span class="space-y-0.5">
                  <span class="block text-xs font-semibold text-slate-900">What If?</span>
                  <span class="block text-xs leading-tight text-slate-600">
                    Explore counterfactuals
                  </span>
                </span>
              </button>
            </div>

            <%!-- Clarity --%>
            <div>
              <p class="mb-2 text-[10px] font-semibold uppercase tracking-wider text-slate-500">
                Clarity
              </p>
              <button
                type="button"
                class="w-full group flex flex-col items-start gap-2 rounded-lg border border-orange-200/80 bg-gradient-to-br from-white to-orange-50/50 px-3 py-2.5 text-left shadow-sm transition hover:-translate-y-0.5 hover:border-orange-300 hover:shadow-md disabled:cursor-not-allowed disabled:opacity-50"
                phx-click="node_simplify"
                phx-value-id={@node && @node.id}
                disabled={is_nil(@graph_id)}
                title="Simplify — Make accessible to all"
              >
                <span class="inline-flex items-center justify-center rounded-lg bg-orange-100 p-1.5 text-orange-700">
                  <.icon name="hero-book-open" class="h-4 w-4" />
                </span>
                <span class="space-y-0.5">
                  <span class="block text-xs font-semibold text-slate-900">Simplify</span>
                  <span class="block text-xs leading-tight text-slate-600">
                    Make it accessible to all
                  </span>
                </span>
              </button>
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
