defmodule DialecticWeb.InquiryActionsComp do
  use DialecticWeb, :live_component
  import DialecticWeb.KeyboardComponents

  alias DialecticWeb.ColUtils

  @critical_tool_sections [
    %{
      title: "Understand",
      tools: [
        %{
          key: "clarify",
          icon: ColUtils.advanced_tool_icon("clarify"),
          label: "Clarify Terms",
          blurb: ColUtils.advanced_tool_description("clarify")
        },
        %{
          key: "assumptions",
          icon: ColUtils.advanced_tool_icon("assumptions"),
          label: "Assumptions",
          blurb: ColUtils.advanced_tool_description("assumptions")
        },
        %{
          key: "says_who",
          icon: ColUtils.advanced_tool_icon("says_who"),
          label: "Source Check",
          blurb: ColUtils.advanced_tool_description("says_who")
        },
        %{
          key: "steel_man",
          icon: ColUtils.advanced_tool_icon("steel_man"),
          label: "Steel Man",
          blurb: ColUtils.advanced_tool_description("steel_man")
        }
      ]
    },
    %{
      title: "Challenge",
      tools: [
        %{
          key: "counterexample",
          icon: ColUtils.advanced_tool_icon("counterexample"),
          label: "Test",
          blurb: ColUtils.advanced_tool_description("counterexample")
        },
        %{
          key: "who_disagrees",
          icon: ColUtils.advanced_tool_icon("who_disagrees"),
          label: "Other Perspectives",
          blurb: ColUtils.advanced_tool_description("who_disagrees")
        }
      ]
    },
    %{
      title: "Expand",
      tools: [
        %{
          key: "implications",
          icon: ColUtils.advanced_tool_icon("implications"),
          label: "Implications",
          blurb: ColUtils.advanced_tool_description("implications")
        },
        %{
          key: "blind_spots",
          icon: ColUtils.advanced_tool_icon("blind_spots"),
          label: "Blind Spots",
          blurb: ColUtils.advanced_tool_description("blind_spots")
        },
        %{
          key: "what_if",
          icon: ColUtils.advanced_tool_icon("what_if"),
          label: "What If",
          blurb: ColUtils.advanced_tool_description("what_if")
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
     |> assign_new(:node, fn -> nil end)
     |> assign_new(:current_user, fn -> nil end)
     |> assign_new(:user, fn -> nil end)
     |> assign_new(:form, fn ->
       to_form(Dialectic.Graph.Vertex.changeset(%Dialectic.Graph.Vertex{}))
     end)
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
      <div data-keyboard-composer class="space-y-2.5 scroll-mt-6 scroll-mb-6">
        <div
          :if={!@highlight_only}
          id={
            if(@context == :node,
              do: "node-custom-inquiry-#{@node.id}",
              else: "selection-custom-inquiry-#{@owner_id}"
            )
          }
          class="relative min-w-0"
        >
          <.live_component
            module={DialecticWeb.AskFormComp}
            id={
              if(@context == :node, do: "global-chat-form", else: "selection-input-form-#{@owner_id}")
            }
            input_id={
              if(@context == :node,
                do: "global-chat-input",
                else: "selection-question-input-#{@owner_id}"
              )
            }
            context={@context}
            prompt_mode={@prompt_mode}
            form={@form}
            graph_id={@graph_id}
            current_user={@current_user}
            node={@node}
            show_context={false}
            guided_learning?={@context in [:node, :answer]}
            embedded
            show_tools
            tools_open={@advanced_tools_open}
            tools_target={if(@context == :node, do: @myself)}
            tools_button_id={advanced_toggle_id(assigns)}
            tools_menu_id={tools_menu_id(assigns)}
            query_origin={if(@context == :node, do: "node_action_bar")}
            disabled={!@can_edit}
          >
            <:quick_actions>
              <%= if @context in [:selection, :answer] do %>
                <.tool_button
                  :if={@context == :selection}
                  id={"selection-action-highlight-#{@owner_id}"}
                  icon="hero-bookmark"
                  label="Highlight"
                  tone="highlight"
                  shortcut="h"
                  selection_action="highlight_only"
                  disable_if_highlight="true"
                  disabled={!@can_edit}
                  compact
                />
                <.tool_button
                  id={"selection-action-explain-#{@owner_id}"}
                  icon="hero-question-mark-circle"
                  label="Explain"
                  description="Make this idea easier to understand."
                  tone="explain"
                  shortcut="e"
                  selection_action="explain"
                  disable_if_links="explain"
                  disabled={!@can_edit}
                  compact
                />
                <.tool_button
                  id={action_id(assigns, "pros-cons")}
                  icon="hero-scale"
                  label="Pro | Con"
                  description="Weigh supporting and opposing arguments."
                  tone="pros_cons"
                  shortcut="a"
                  selection_action="pros_cons"
                  disable_if_links="pro,con"
                  disabled={!@can_edit}
                  compact
                />
                <.tool_button
                  id={action_id(assigns, "related")}
                  icon="hero-light-bulb"
                  label="Related ideas"
                  description="Find connections worth exploring."
                  tone="ideas"
                  shortcut="r"
                  selection_action="related_ideas"
                  disable_if_links="related_idea"
                  disabled={!@can_edit}
                  compact
                />
              <% else %>
                <.tool_button
                  id={action_id(assigns, "pros-cons")}
                  icon="hero-scale"
                  label="Pro | Con"
                  description="Weigh supporting and opposing arguments."
                  tone="pros_cons"
                  shortcut="a"
                  event="node_branch"
                  node_id={@node.id}
                  disabled={!@can_edit}
                  compact
                />
                <.tool_button
                  id={action_id(assigns, "connect")}
                  icon="hero-arrows-pointing-in"
                  label="Synthesis"
                  description="Connect ideas to build a new understanding."
                  tone="synthesis"
                  shortcut="c"
                  event={
                    Phoenix.LiveView.JS.dispatch("toggle-panel",
                      to: "#graph-layout",
                      detail: %{id: "combine-drawer"}
                    )
                    |> Phoenix.LiveView.JS.push("node_combine")
                  }
                  node_id={@node.id}
                  disabled={!@can_edit}
                  compact
                />
                <.tool_button
                  id={action_id(assigns, "related")}
                  icon="hero-light-bulb"
                  label="Related ideas"
                  description="Find connections worth exploring."
                  tone="ideas"
                  shortcut="r"
                  event="node_related_ideas"
                  node_id={@node.id}
                  disabled={!@can_edit}
                  compact
                />
              <% end %>
            </:quick_actions>
            <.advanced_tools
              context={@context}
              sections={@critical_tool_sections}
              graph_id={@graph_id}
              node={@node}
              owner_id={@owner_id}
              can_edit={@can_edit}
            />
          </.live_component>
        </div>
        <div :if={@highlight_only}>
          <.tool_button
            id={"selection-action-highlight-#{@owner_id}"}
            icon="hero-bookmark"
            label="Highlight"
            tone="highlight"
            description="Save this passage without an AI reply."
            shortcut="h"
            selection_action="highlight_only"
            disable_if_highlight="true"
            disabled={!@can_edit}
          />
        </div>
        <p :if={!@highlight_only} class="hidden px-1 text-[10px] text-slate-500 md:block">
          <%= if @context in [:selection, :answer] do %>
            / to write · T for tools · Esc to leave the form, then close · Option/Alt + Shift + A / R / E{if(
              @context == :selection,
              do: " / H",
              else: ""
            )} to use tools when not typing
          <% else %>
            T for tools · Esc to leave the form · Option/Alt + Shift + A / C / R / B to use tools when not typing
          <% end %>
        </p>
      </div>
    </div>
    """
  end

  defp advanced_tools(assigns) do
    assigns = assign_new(assigns, :owner_id, fn -> nil end)

    ~H"""
    <div class="space-y-3">
      <div :for={section <- @sections} class="space-y-1.5">
        <h4 class="px-2 py-1 text-[10px] font-semibold uppercase tracking-wider text-slate-500">
          {section.title}
        </h4>
        <div class="inquiry-tools-toolbar grid min-w-0 grid-cols-1 gap-2 sm:grid-cols-2">
          <.tool_button
            :for={tool <- section.tools}
            id={tool_id(assigns, tool.key)}
            event={if(@context == :node, do: "node_#{tool.key}")}
            node_id={if(@context == :node, do: @node.id)}
            selection_action={if(@context in [:selection, :answer], do: tool.key)}
            disable_if_links={if(@context in [:selection, :answer], do: tool.key)}
            icon={tool.icon}
            label={tool.label}
            tone={tool.key}
            description={tool.blurb}
            rest={%{"title" => tool.blurb}}
            disabled={!@can_edit}
            compact
          />
        </div>
      </div>
    </div>
    """
  end

  defp tool_button(assigns) do
    assigns =
      assigns
      |> assign_new(:shortcut, fn -> nil end)
      |> assign_new(:selection_action, fn -> nil end)
      |> assign_new(:disable_if_links, fn -> nil end)
      |> assign_new(:disable_if_highlight, fn -> nil end)
      |> assign_new(:event, fn -> nil end)
      |> assign_new(:node_id, fn -> nil end)
      |> assign_new(:description, fn -> nil end)
      |> assign_new(:compact, fn -> false end)
      |> assign_new(:pressed, fn -> nil end)
      |> assign_new(:rest, fn -> %{} end)

    ~H"""
    <button
      id={@id}
      type="button"
      phx-click={@event}
      phx-value-id={@node_id}
      aria-pressed={if(is_boolean(@pressed), do: to_string(@pressed))}
      aria-keyshortcuts={@shortcut && "Alt+Shift+#{String.upcase(@shortcut)}"}
      data-selection-action={@selection_action}
      data-reader-shortcut={@shortcut}
      data-disable-if-links={@disable_if_links}
      data-disable-if-highlight={@disable_if_highlight}
      disabled={@disabled}
      {@rest}
      class={[
        "group/tool flex min-h-11 min-w-0 rounded-lg border bg-white text-left text-slate-950 transition duration-150 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-teal-700 disabled:cursor-not-allowed disabled:opacity-50",
        if(@compact,
          do:
            "inquiry-tool-compact aria-pressed:border-amber-800 aria-pressed:bg-amber-100 items-center gap-2 border-stone-300 py-1.5 pl-1.5 pr-3 hover:border-teal-700 hover:bg-stone-50",
          else:
            "w-full items-start gap-3 border-stone-300 p-2.5 hover:border-teal-700 hover:bg-stone-50"
        )
      ]}
    >
      <span class={[
        "inline-flex h-7 w-7 shrink-0 items-center justify-center rounded-lg",
        ColUtils.tool_color_class(@tone)
      ]}>
        <.icon name={@icon} class="h-4 w-4" />
      </span>
      <span class={[
        "min-w-0 flex-1",
        @compact && !@description && "flex items-center justify-between gap-2"
      ]}>
        <span data-tool-label class="block min-w-0 text-[13px] font-medium leading-5">{@label}</span>
        <.shortcut_keycap
          :if={@compact && @shortcut}
          key={@shortcut}
          modifier="alt"
          shift
        />
        <span :if={@description} class="mt-0.5 block text-xs leading-4 text-slate-700">{@description}</span>
      </span>
      <.shortcut_keycap :if={!@compact && @shortcut} key={@shortcut} modifier="alt" shift quiet />
    </button>
    """
  end

  defp action_id(%{context: :node, graph_id: graph_id, node: node}, action),
    do: "node-tool-#{action}-#{graph_id}-#{node.id}"

  defp action_id(%{owner_id: owner_id}, "pros-cons"),
    do: "selection-action-pros-cons-#{owner_id}"

  defp action_id(%{owner_id: owner_id}, "related"),
    do: "selection-action-related-#{owner_id}"

  defp tools_menu_id(%{context: :node, node: node}), do: "node-tools-popover-#{node.id}"
  defp tools_menu_id(%{owner_id: owner_id}), do: "selection-tools-popover-#{owner_id}"

  defp advanced_toggle_id(%{context: :node, graph_id: graph_id, node: node}),
    do: "node-tools-more-#{graph_id}-#{node.id}"

  defp advanced_toggle_id(%{owner_id: owner_id}),
    do: "selection-advanced-tools-toggle-#{owner_id}"

  defp tool_id(%{context: :node, graph_id: graph_id, node: node}, key),
    do: "node-tool-#{key}-#{graph_id}-#{node.id}"

  defp tool_id(%{owner_id: owner_id}, key), do: "selection-tool-#{owner_id}-#{key}"
end
