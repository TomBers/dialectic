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

  @critical_tool_sections [
    %{
      title: "Understand",
      tools: [
        %{
          key: "clarify",
          event: "node_clarify",
          icon: "hero-light-bulb",
          label: "Clarify Terms",
          blurb: "What do we mean?",
          title:
            "Clarify Terms: Identify key terms, hidden ambiguity, conceptual boundaries, and what would count as evidence."
        },
        %{
          key: "assumptions",
          event: "node_assumptions",
          icon: "hero-cube-transparent",
          label: "Assumptions",
          blurb: "What has to be true?",
          title:
            "Assumptions: Reveal what must be true for this claim to work. Example: 'Remote work is better' assumes people have suitable home spaces, reliable internet, and self-discipline."
        },
        %{
          key: "says_who",
          event: "node_says_who",
          icon: "hero-user",
          label: "Source Check",
          blurb: "Says who?",
          title:
            "Source Check: Question the authority and evidence behind claims. Example: 'Studies show X' — which studies? Who funded them? What was the sample size? Are there conflicting studies?"
        },
        %{
          key: "steel_man",
          event: "node_steel_man",
          icon: "hero-star",
          label: "Steel Man",
          blurb: "Strongest argument",
          title:
            "Steel Man: Build the strongest, most charitable version of this argument — the opposite of a straw man. Example: If someone says 'We should ban cars', the steel man would be 'In dense urban areas, reducing car dependency through better public transit and walkable design could improve health, reduce emissions, and create more livable communities.'"
        }
      ]
    },
    %{
      title: "Challenge",
      tools: [
        %{
          key: "counterexample",
          event: "node_counterexample",
          icon: "hero-x-mark",
          label: "Test",
          blurb: "Is that always true?",
          title:
            "Test: Find counterexamples that challenge this claim. Example: If someone claims 'All successful people wake up early', counterexamples include successful artists, programmers, and entrepreneurs who are night owls."
        },
        %{
          key: "who_disagrees",
          event: "node_who_disagrees",
          icon: "hero-users",
          label: "Other Perspectives",
          blurb: "Who disagrees?",
          title:
            "Who Disagrees: Explore different perspectives and opposing viewpoints. Example: For 'Everyone should go to college', consider vocational experts, entrepreneurs, and trades professionals."
        }
      ]
    },
    %{
      title: "Expand",
      tools: [
        %{
          key: "implications",
          event: "node_implications",
          icon: "hero-arrow-trending-up",
          label: "Implications",
          blurb: "If true, then what?",
          title:
            "Implications: What would happen if this were true? Example: 'Universal basic income' implies changes to work incentives, tax systems, inflation, and social safety nets."
        },
        %{
          key: "blind_spots",
          event: "node_blind_spots",
          icon: "hero-eye-slash",
          label: "Blind Spots",
          blurb: "What are we missing?",
          title:
            "Blind Spots: Identify perspectives, factors, or constraints being overlooked. Example: A tech solution might ignore users without internet access or digital literacy."
        },
        %{
          key: "what_if",
          event: "node_what_if",
          icon: "hero-question-mark-circle",
          label: "What If",
          blurb: "Hypothetical scenarios",
          title:
            "What If: Explore hypothetical scenarios and alternative possibilities. Example: 'What if we had universal healthcare?' or 'What if fossil fuels ran out tomorrow?'"
        }
      ]
    }
  ]

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
    assigns =
      assign(assigns, critical_tool_sections: @critical_tool_sections)

    ~H"""
    <div
      class="mt-3 min-w-0 space-y-3 break-words sm:mt-4"
      data-external="true"
      data-role="action-toolbar"
    >
      <% info = delete_info(assigns) %>

      <section
        class="min-w-0 overflow-hidden rounded-[1.25rem] border border-slate-200/90 bg-slate-50/45 p-4 sm:p-5"
        aria-labelledby={"keep-exploring-title-#{@node && @node.id}"}
      >
        <div class="flex flex-col gap-4">
          <div class="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
            <div class="min-w-0">
              <p class="text-[10px] font-semibold uppercase tracking-[0.16em] text-teal-700">
                Keep exploring
              </p>
              <h3
                id={"keep-exploring-title-#{@node && @node.id}"}
                class="mt-1.5 font-serif text-[1.45rem] font-semibold leading-tight tracking-tight text-slate-950"
              >
                Take this idea further
              </h3>
              <p class="mt-1.5 text-sm leading-6 text-slate-600">
                Choose how you want to deepen your understanding.
              </p>
            </div>

            <span
              :if={@can_edit == false}
              class="inline-flex self-start items-center gap-1.5 rounded-full border border-amber-200 bg-amber-50 px-2.5 py-1 text-xs font-semibold text-amber-700"
              title="Graph is locked; editing is disabled"
            >
              <.icon name="hero-lock-closed" class="h-3.5 w-3.5" />
              <span>Graph locked</span>
            </span>
          </div>

          <div class="divide-y divide-slate-200/80 rounded-xl border border-slate-200/80 bg-white/55 px-3">
            <button
              id={"node-tool-pro-con-#{@graph_id}-#{@node && @node.id}"}
              type="button"
              class="group grid w-full min-w-0 grid-cols-[1.75rem_minmax(0,1fr)_auto] items-start gap-3 py-3.5 text-left transition active:scale-[0.995] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-emerald-200 focus-visible:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50"
              phx-click="node_branch"
              phx-value-id={@node && @node.id}
              disabled={is_nil(@graph_id)}
              title="Create supporting and opposing branches from this point"
            >
              <span class="mt-0.5 inline-flex h-7 w-7 items-center justify-center rounded-lg bg-white text-emerald-700 ring-1 ring-slate-200/90">
                <.icon name="hero-scale" class="h-4 w-4" />
              </span>
              <span class="min-w-0">
                <span class="block text-[15px] font-semibold leading-5 text-slate-900">
                  Test both sides
                </span>
                <span class="mt-0.5 block text-[13px] leading-5 text-slate-500">
                  Build the strongest case for and against this idea.
                </span>
              </span>
              <.icon
                name="hero-arrow-right"
                class="mt-1 h-4 w-4 text-slate-400 transition group-hover:translate-x-0.5 group-hover:text-emerald-700"
              />
            </button>

            <button
              id={"node-tool-connect-#{@graph_id}-#{@node && @node.id}"}
              type="button"
              class="group grid w-full min-w-0 grid-cols-[1.75rem_minmax(0,1fr)_auto] items-start gap-3 py-3.5 text-left transition active:scale-[0.995] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-violet-200 focus-visible:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50"
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
              aria-label="Connect this idea with another"
              title="Connect this idea with another"
            >
              <span class="mt-0.5 inline-flex h-7 w-7 items-center justify-center rounded-lg bg-white text-violet-700 ring-1 ring-slate-200/90">
                <.icon name="hero-arrows-pointing-in" class="h-4 w-4" />
              </span>
              <span class="min-w-0">
                <span class="block text-[15px] font-semibold leading-5 text-slate-900">
                  Connect another idea
                </span>
                <span class="mt-0.5 block text-[13px] leading-5 text-slate-500">
                  See what emerges when two points meet.
                </span>
              </span>
              <.icon
                name="hero-arrow-right"
                class="mt-1 h-4 w-4 text-slate-400 transition group-hover:translate-x-0.5 group-hover:text-violet-700"
              />
            </button>

            <button
              id={"node-tool-related-#{@graph_id}-#{@node && @node.id}"}
              type="button"
              class="group grid w-full min-w-0 grid-cols-[1.75rem_minmax(0,1fr)_auto] items-start gap-3 py-3.5 text-left transition active:scale-[0.995] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-orange-200 focus-visible:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50"
              phx-click="node_related_ideas"
              phx-value-id={@node && @node.id}
              disabled={is_nil(@graph_id)}
              title="Find related ideas"
              data-action="related-ideas"
            >
              <span class="mt-0.5 inline-flex h-7 w-7 items-center justify-center rounded-lg bg-white text-orange-700 ring-1 ring-slate-200/90">
                <.icon name="hero-light-bulb" class="h-4 w-4" />
              </span>
              <span class="min-w-0">
                <span class="block text-[15px] font-semibold leading-5 text-slate-900">
                  Find related ideas
                </span>
                <span class="mt-0.5 block text-[13px] leading-5 text-slate-500">
                  Add useful concepts, comparisons, and nearby directions.
                </span>
              </span>
              <.icon
                name="hero-arrow-right"
                class="mt-1 h-4 w-4 text-slate-400 transition group-hover:translate-x-0.5 group-hover:text-orange-700"
              />
            </button>
          </div>

          <div>
            <button
              id={"node-tools-more-#{@graph_id}-#{@node && @node.id}"}
              type="button"
              class="flex w-full min-w-0 items-center justify-between gap-3 rounded-xl px-2 py-2.5 text-left transition hover:bg-white/75 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-slate-300"
              phx-click="toggle_advanced_tools"
              phx-target={@myself}
              aria-expanded={to_string(@advanced_tools_open)}
            >
              <span class="min-w-0">
                <span class="block text-sm font-semibold text-slate-900">
                  More ways to examine this idea
                </span>
                <span class="mt-0.5 block text-xs leading-5 text-slate-500">
                  Clarify it, challenge it, or follow its implications.
                </span>
              </span>
              <.icon
                name="hero-chevron-down"
                class={
                  if @advanced_tools_open,
                    do: "h-4 w-4 shrink-0 rotate-180 text-slate-400 transition-transform",
                    else: "h-4 w-4 shrink-0 text-slate-400 transition-transform"
                }
              />
            </button>

            <div class={[
              "mt-3 space-y-4 border-t border-slate-200/70 pt-4",
              !@advanced_tools_open && "hidden"
            ]}>
              <div :for={section <- @critical_tool_sections} class="space-y-1.5">
                <h4 class="px-1 text-[11px] font-semibold uppercase tracking-[0.14em] text-slate-500">
                  {section.title}
                </h4>
                <div class="grid min-w-0 gap-1 sm:grid-cols-2">
                  <button
                    :for={tool <- section.tools}
                    id={"node-tool-#{tool.key}-#{@graph_id}-#{@node && @node.id}"}
                    type="button"
                    class="group flex min-w-0 items-start gap-2.5 rounded-xl border border-transparent px-2.5 py-2.5 text-left transition hover:border-slate-200 hover:bg-white active:scale-[0.995] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-slate-300 disabled:cursor-not-allowed disabled:opacity-50"
                    phx-click={tool.event}
                    phx-value-id={@node && @node.id}
                    disabled={is_nil(@graph_id)}
                    title={tool.title}
                  >
                    <span class={[
                      "mt-0.5 inline-flex h-6 w-6 shrink-0 items-center justify-center rounded-md bg-white ring-1 ring-slate-200/80",
                      ColUtils.advanced_tool_text_class(tool.key)
                    ]}>
                      <.icon name={tool.icon} class="h-3.5 w-3.5" />
                    </span>
                    <span class="min-w-0">
                      <span class="block text-xs font-semibold leading-4 text-slate-900">
                        {tool.label}
                      </span>
                      <span class="mt-0.5 block text-xs leading-4 text-slate-500">
                        {tool.blurb}
                      </span>
                    </span>
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      <div class="flex flex-col gap-3 px-1 py-1 sm:flex-row sm:items-start sm:justify-between sm:gap-4">
        <div class="max-w-xl">
          <p class="text-[10px] font-semibold uppercase tracking-[0.14em] text-slate-400">
            Node settings
          </p>
          <p class="mt-1 text-xs leading-5 text-slate-500">
            Delete is available to the author when nothing else depends on this point.
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
    """
  end
end
