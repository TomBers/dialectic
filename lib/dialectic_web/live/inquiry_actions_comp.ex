defmodule DialecticWeb.InquiryActionsComp do
  use DialecticWeb, :live_component

  alias DialecticWeb.ColUtils

  @critical_tool_sections [
    %{
      title: "Understand",
      tools: [
        %{
          key: "clarify",
          icon: "hero-light-bulb",
          label: "Clarify Terms",
          blurb: "What do we mean?"
        },
        %{
          key: "assumptions",
          icon: "hero-cube-transparent",
          label: "Assumptions",
          blurb: "What has to be true?"
        },
        %{key: "says_who", icon: "hero-user", label: "Source Check", blurb: "Says who?"},
        %{key: "steel_man", icon: "hero-star", label: "Steel Man", blurb: "Strongest argument"}
      ]
    },
    %{
      title: "Challenge",
      tools: [
        %{
          key: "counterexample",
          icon: "hero-x-mark",
          label: "Test",
          blurb: "Is that always true?"
        },
        %{
          key: "who_disagrees",
          icon: "hero-users",
          label: "Other Perspectives",
          blurb: "Who disagrees?"
        }
      ]
    },
    %{
      title: "Expand",
      tools: [
        %{
          key: "implications",
          icon: "hero-arrow-trending-up",
          label: "Implications",
          blurb: "If true, then what?"
        },
        %{
          key: "blind_spots",
          icon: "hero-eye-slash",
          label: "Blind Spots",
          blurb: "What are we missing?"
        },
        %{
          key: "what_if",
          icon: "hero-question-mark-circle",
          label: "What If",
          blurb: "Hypothetical scenarios"
        }
      ]
    }
  ]

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:owner_id, fn -> assigns[:id] end)
     |> assign_new(:advanced_tools_open, fn -> false end)
     |> assign_new(:highlight_only, fn -> false end)
     |> assign_new(:form, fn -> nil end)
     |> assign_new(:prompt_mode, fn -> "university" end)
     |> assign_new(:ask_question, fn -> true end)}
  end

  @impl true
  def handle_event("toggle_advanced_tools", _params, socket) do
    {:noreply, assign(socket, :advanced_tools_open, !socket.assigns.advanced_tools_open)}
  end

  def handle_event("close_advanced_tools", _params, socket) do
    {:noreply, assign(socket, :advanced_tools_open, false)}
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :critical_tool_sections, @critical_tool_sections)

    ~H"""
    <div id={"#{@id}-content"} class="min-w-0">
      <%= if @context == :node do %>
        <div class="space-y-2.5">
          <div
            id={"node-custom-inquiry-#{@node.id}"}
            phx-click-away={if(@advanced_tools_open, do: "close_advanced_tools")}
            phx-target={@myself}
            class="relative rounded-2xl border border-slate-300 bg-white p-2 shadow-sm transition focus-within:border-indigo-400 focus-within:ring-4 focus-within:ring-indigo-100/70"
          >
            <.live_component
              module={DialecticWeb.AskFormComp}
              id="global-chat-form"
              form={@form}
              ask_question={@ask_question}
              prompt_mode={@prompt_mode}
              graph_id={@graph_id}
              node={@node}
              show_context={false}
              embedded
              show_tools
              tools_open={@advanced_tools_open}
              tools_target={@myself}
              tools_button_id={advanced_toggle_id(assigns)}
              placeholder="Ask anything about this response..."
              disabled={!@can_edit}
            />

            <div
              :if={@advanced_tools_open}
              id={"node-tools-popover-#{@node.id}"}
              class="absolute inset-x-0 top-full z-30 mt-2 rounded-2xl border border-slate-200 bg-white p-3 shadow-xl ring-1 ring-slate-950/5"
            >
              <.advanced_tools
                context={:node}
                sections={@critical_tool_sections}
                graph_id={@graph_id}
                node={@node}
                can_edit={@can_edit}
              />
            </div>
          </div>

          <div id={"node-suggestions-#{@node.id}"} class="grid grid-cols-3 gap-2 px-1">
            <.node_chip
              id={action_id(assigns, "pros-cons")}
              icon="hero-scale"
              label="Test both sides"
              accent="emerald"
              event="node_branch"
              node_id={@node.id}
              disabled={!@can_edit}
            />
            <.node_chip
              id={action_id(assigns, "connect")}
              icon="hero-arrows-pointing-in"
              label="Connect"
              accent="violet"
              event={
                Phoenix.LiveView.JS.dispatch("toggle-panel",
                  to: "#graph-layout",
                  detail: %{id: "combine-drawer"}
                )
                |> Phoenix.LiveView.JS.push("node_combine")
              }
              node_id={@node.id}
              disabled={!@can_edit}
            />
            <.node_chip
              id={action_id(assigns, "related")}
              icon="hero-light-bulb"
              label="Related ideas"
              accent="orange"
              event="node_related_ideas"
              node_id={@node.id}
              disabled={!@can_edit}
            />
          </div>
        </div>
      <% else %>
        <div class="space-y-3">
          <div
            :if={!@highlight_only}
            class="relative rounded-2xl border border-slate-300 bg-white p-2 shadow-sm transition focus-within:border-indigo-400 focus-within:ring-4 focus-within:ring-indigo-100/70"
          >
            <form id={"selection-input-form-#{@owner_id}"} data-selection-input-form class="min-w-0">
              <textarea
                name="question"
                data-selection-input
                rows="2"
                phx-hook="AutoExpandTextarea"
                id={"selection-question-input-#{@owner_id}"}
                class="max-h-[8rem] min-h-[4.5rem] w-full resize-none border-0 bg-transparent px-2.5 py-2 text-sm text-slate-800 outline-none placeholder:text-slate-400 focus:ring-0"
                placeholder="Ask anything about this passage..."
                aria-label="Ask about the selected passage"
                autocomplete="off"
                disabled={!@can_edit}
              ></textarea>

              <div class="mt-1 flex items-center gap-1.5 border-t border-slate-100 px-1 pt-2">
                <div class="flex min-w-0 items-center gap-1">
                  <button
                    id={advanced_toggle_id(assigns)}
                    type="button"
                    data-selection-advanced-toggle="true"
                    aria-expanded="false"
                    class="inline-flex h-8 shrink-0 items-center gap-1 rounded-full px-2.5 text-xs font-semibold text-slate-600 transition hover:bg-slate-100 hover:text-slate-900 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-indigo-300"
                  >
                    <.icon name="hero-plus" class="h-3.5 w-3.5" />
                    <span>Tools</span>
                  </button>

                  <span
                    data-selection-question-count
                    class="hidden rounded-full bg-indigo-50 px-2 py-1 text-[10px] font-medium text-indigo-700 ring-1 ring-indigo-200"
                  >
                  </span>
                  <span
                    data-selection-comment-count
                    class="hidden rounded-full bg-emerald-50 px-2 py-1 text-[10px] font-medium text-emerald-700 ring-1 ring-emerald-200"
                  >
                  </span>
                </div>

                <div class="ml-auto flex items-center gap-1">
                  <button
                    id={"selection-submit-comment-#{@owner_id}"}
                    type="submit"
                    data-selection-input-submit
                    data-selection-submit-action="comment"
                    disabled={!@can_edit}
                    class="inline-flex h-8 items-center gap-1 rounded-full px-2.5 text-xs font-semibold text-slate-600 transition hover:bg-slate-100 hover:text-slate-900 disabled:cursor-not-allowed disabled:opacity-50"
                    title="Add your comment without an AI reply"
                  >
                    <.icon name="hero-chat-bubble-left-ellipsis" class="h-3.5 w-3.5" />
                    <span>Comment</span>
                  </button>
                  <button
                    id={"selection-submit-ask-#{@owner_id}"}
                    type="submit"
                    data-selection-input-submit
                    data-selection-submit-action="ask_question"
                    disabled={!@can_edit}
                    class="inline-flex h-8 items-center gap-1 rounded-full bg-slate-950 px-3 text-xs font-semibold text-white shadow-sm transition hover:bg-slate-800 disabled:cursor-not-allowed disabled:opacity-50"
                    title="Ask and get an AI response"
                  >
                    <span>Ask</span>
                    <.icon name="hero-arrow-up" class="h-3.5 w-3.5" />
                  </button>
                </div>
              </div>
            </form>

            <div
              data-selection-advanced-tools="true"
              class="mt-3 hidden rounded-2xl border border-slate-200 bg-slate-50/70 p-3 shadow-inner"
            >
              <.advanced_tools
                context={:selection}
                sections={@critical_tool_sections}
                owner_id={@owner_id}
                can_edit={@can_edit}
              />
            </div>
          </div>

          <div class={[
            "grid gap-2",
            if(@highlight_only, do: "grid-cols-1", else: "grid-cols-2")
          ]}>
            <.action_card
              :if={!@highlight_only}
              id={"selection-action-explain-#{@owner_id}"}
              icon="hero-question-mark-circle"
              label="Explain"
              accent="sky"
              selection_action="explain"
              disable_if_links="explain"
              disabled={!@can_edit}
            />
            <.action_card
              id={"selection-action-highlight-#{@owner_id}"}
              icon="hero-bookmark"
              label="Highlight"
              accent="amber"
              selection_action="highlight_only"
              disable_if_highlight="true"
              disabled={!@can_edit}
            />
            <.action_card
              :if={!@highlight_only}
              id={action_id(assigns, "pros-cons")}
              icon="hero-scale"
              label="Test both sides"
              accent="emerald"
              selection_action="pros_cons"
              disable_if_links="pro,con"
              disabled={!@can_edit}
            />
            <.action_card
              :if={!@highlight_only}
              id={action_id(assigns, "related")}
              icon="hero-light-bulb"
              label="Related ideas"
              accent="orange"
              selection_action="related_ideas"
              disable_if_links="related_idea"
              disabled={!@can_edit}
            />
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp node_chip(assigns) do
    ~H"""
    <button
      id={@id}
      type="button"
      phx-click={@event}
      phx-value-id={@node_id}
      disabled={@disabled}
      class={[
        "inline-flex min-h-9 w-full min-w-0 items-center justify-center gap-1.5 rounded-xl border px-2 py-1.5 text-center text-xs font-semibold leading-tight shadow-sm transition focus-visible:outline-none focus-visible:ring-2 disabled:cursor-not-allowed disabled:opacity-50",
        node_chip_class(@accent)
      ]}
    >
      <.icon name={@icon} class="h-3.5 w-3.5 shrink-0" />
      <span>{@label}</span>
    </button>
    """
  end

  defp advanced_tools(assigns) do
    assigns = assign_new(assigns, :owner_id, fn -> nil end)

    ~H"""
    <div class="space-y-3">
      <div :for={section <- @sections} class="space-y-1.5">
        <h4 class="px-1 text-[10px] font-semibold uppercase tracking-[0.14em] text-slate-500">
          {section.title}
        </h4>
        <div class={[
          "grid min-w-0 grid-cols-2 gap-1.5",
          @context == :selection && "sm:grid-cols-3"
        ]}>
          <button
            :for={tool <- section.tools}
            id={tool_id(assigns, tool.key)}
            type="button"
            phx-click={if(@context == :node, do: "node_#{tool.key}")}
            phx-value-id={if(@context == :node, do: @node.id)}
            data-selection-action={if(@context == :selection, do: tool.key)}
            data-disable-if-links={if(@context == :selection, do: tool.key)}
            disabled={!@can_edit}
            class={[
              "group flex min-w-0 cursor-pointer items-center gap-2 rounded-lg px-2 py-2 text-left shadow-sm transition hover:-translate-y-px hover:shadow-md focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-slate-300 disabled:cursor-not-allowed disabled:opacity-50",
              ColUtils.advanced_tool_surface_class(tool.key)
            ]}
          >
            <span class={[
              "inline-flex h-7 w-7 shrink-0 items-center justify-center rounded-lg shadow-sm ring-1 ring-inset ring-black/5",
              ColUtils.advanced_tool_icon_class(tool.key)
            ]}>
              <.icon name={tool.icon} class="h-4 w-4" />
            </span>
            <span class="min-w-0">
              <span class="block text-xs font-semibold leading-4 text-slate-900">
                {tool.label}
              </span>
            </span>
          </button>
        </div>
      </div>
    </div>
    """
  end

  defp action_card(assigns) do
    assigns =
      assigns
      |> assign_new(:selection_action, fn -> nil end)
      |> assign_new(:disable_if_links, fn -> nil end)
      |> assign_new(:disable_if_highlight, fn -> nil end)

    ~H"""
    <button
      id={@id}
      type="button"
      data-selection-action={@selection_action}
      data-disable-if-links={@disable_if_links}
      data-disable-if-highlight={@disable_if_highlight}
      disabled={@disabled}
      class={[
        "group flex min-h-11 w-full min-w-0 cursor-pointer items-center gap-2 rounded-xl border px-3 py-2.5 text-left shadow-sm transition hover:-translate-y-px hover:shadow-md focus-visible:z-10 focus-visible:outline-none focus-visible:ring-2 disabled:cursor-not-allowed disabled:opacity-50",
        action_surface_class(@accent)
      ]}
    >
      <span class={[
        "inline-flex h-8 w-8 shrink-0 items-center justify-center rounded-lg shadow-sm ring-1 ring-inset",
        action_icon_class(@accent)
      ]}>
        <.icon name={@icon} class="h-[18px] w-[18px]" />
      </span>
      <span class="min-w-0">
        <span class="block text-sm font-semibold leading-5">{@label}</span>
      </span>
    </button>
    """
  end

  defp action_surface_class("sky"),
    do:
      "border-sky-200 bg-sky-50 text-sky-800 hover:border-sky-300 hover:bg-sky-100 focus-visible:ring-sky-300"

  defp action_surface_class("amber"),
    do:
      "border-amber-200 bg-amber-50 text-amber-800 hover:border-amber-300 hover:bg-amber-100 focus-visible:ring-amber-300"

  defp action_surface_class("emerald"),
    do:
      "border-emerald-200 bg-emerald-50 text-emerald-800 hover:border-emerald-300 hover:bg-emerald-100 focus-visible:ring-emerald-300"

  defp action_surface_class("orange"),
    do:
      "border-orange-200 bg-orange-50 text-orange-800 hover:border-orange-300 hover:bg-orange-100 focus-visible:ring-orange-300"

  defp action_icon_class("sky"), do: "bg-sky-100 text-sky-800 ring-sky-300/80"
  defp action_icon_class("amber"), do: "bg-amber-100 text-amber-800 ring-amber-300/80"
  defp action_icon_class("emerald"), do: "bg-emerald-100 text-emerald-800 ring-emerald-300/80"
  defp action_icon_class("orange"), do: "bg-orange-100 text-orange-800 ring-orange-300/80"

  defp node_chip_class("emerald"),
    do:
      "border-emerald-200 bg-emerald-50 text-emerald-800 hover:border-emerald-300 hover:bg-emerald-100 focus-visible:ring-emerald-300"

  defp node_chip_class("violet"),
    do:
      "border-violet-200 bg-violet-50 text-violet-800 hover:border-violet-300 hover:bg-violet-100 focus-visible:ring-violet-300"

  defp node_chip_class("orange"),
    do:
      "border-orange-200 bg-orange-50 text-orange-800 hover:border-orange-300 hover:bg-orange-100 focus-visible:ring-orange-300"

  defp action_id(%{context: :node, graph_id: graph_id, node: node}, action),
    do: "node-tool-#{action}-#{graph_id}-#{node.id}"

  defp action_id(%{owner_id: owner_id}, "pros-cons"),
    do: "selection-action-pros-cons-#{owner_id}"

  defp action_id(%{owner_id: owner_id}, "related"),
    do: "selection-action-related-#{owner_id}"

  defp advanced_toggle_id(%{context: :node, graph_id: graph_id, node: node}),
    do: "node-tools-more-#{graph_id}-#{node.id}"

  defp advanced_toggle_id(%{owner_id: owner_id}),
    do: "selection-advanced-tools-toggle-#{owner_id}"

  defp tool_id(%{context: :node, graph_id: graph_id, node: node}, key),
    do: "node-tool-#{key}-#{graph_id}-#{node.id}"

  defp tool_id(%{owner_id: owner_id}, key), do: "selection-tool-#{owner_id}-#{key}"
end
