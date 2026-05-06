defmodule DialecticWeb.SelectionActionsComp do
  @moduledoc """
  LiveComponent for handling text selection actions.

  Provides a modal interface for creating highlights, explanations,
  questions, pros/cons, and related ideas from selected text.
  """
  use DialecticWeb, :live_component
  alias Dialectic.Highlights
  alias DialecticWeb.ColUtils

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(
       visible: false,
       selected_text: nil,
       node_id: nil,
       offsets: nil,
       highlight: nil,
       links: [],
       ask_question: true,
       show_advanced_tools: false
     )}
  end

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:visible, fn -> false end)}
  end

  @impl true
  def handle_event("show", params, socket) do
    %{
      "selectedText" => selected_text,
      "nodeId" => node_id,
      "offsets" => offsets
    } = params

    # Query existing highlight for this selection
    {highlight, links} =
      case Highlights.get_highlight_for_selection(
             socket.assigns.graph_id,
             node_id,
             offsets["start"],
             offsets["end"]
           ) do
        nil -> {nil, []}
        h -> {h, h.links}
      end

    {:noreply,
     socket
     |> assign(
       visible: true,
       selected_text: selected_text,
       node_id: node_id,
       offsets: offsets,
       highlight: highlight,
       links: links
     )}
  end

  @impl true
  def handle_event("close", _params, socket) do
    {:noreply, assign(socket, visible: false)}
  end

  @impl true
  def handle_event("explain", _params, socket) do
    send_action_to_parent(socket, :explain)
    {:noreply, assign(socket, visible: false)}
  end

  @impl true
  def handle_event("highlight_only", _params, socket) do
    send_action_to_parent(socket, :highlight_only)
    {:noreply, assign(socket, visible: false)}
  end

  @impl true
  def handle_event("pros_cons", _params, socket) do
    send_action_to_parent(socket, :pros_cons)
    {:noreply, assign(socket, visible: false)}
  end

  @impl true
  def handle_event("related_ideas", _params, socket) do
    send_action_to_parent(socket, :related_ideas)
    {:noreply, assign(socket, visible: false)}
  end

  @impl true
  def handle_event("clarify", _params, socket) do
    send_action_to_parent(socket, :clarify)
    {:noreply, assign(socket, visible: false)}
  end

  @impl true
  def handle_event("assumptions", _params, socket) do
    send_action_to_parent(socket, :assumptions)
    {:noreply, assign(socket, visible: false)}
  end

  @impl true
  def handle_event("counterexample", _params, socket) do
    send_action_to_parent(socket, :counterexample)
    {:noreply, assign(socket, visible: false)}
  end

  @impl true
  def handle_event("implications", _params, socket) do
    send_action_to_parent(socket, :implications)
    {:noreply, assign(socket, visible: false)}
  end

  @impl true
  def handle_event("steel_man", _params, socket) do
    send_action_to_parent(socket, :steel_man)
    {:noreply, assign(socket, visible: false)}
  end

  @impl true
  def handle_event("says_who", _params, socket) do
    send_action_to_parent(socket, :says_who)
    {:noreply, assign(socket, visible: false)}
  end

  @impl true
  def handle_event("second_order", _params, socket) do
    send_action_to_parent(socket, :second_order)
    {:noreply, assign(socket, visible: false)}
  end

  @impl true
  def handle_event("simplify", _params, socket) do
    send_action_to_parent(socket, :simplify)
    {:noreply, assign(socket, visible: false)}
  end

  @impl true
  def handle_event("blind_spots", _params, socket) do
    send_action_to_parent(socket, :blind_spots)
    {:noreply, assign(socket, visible: false)}
  end

  @impl true
  def handle_event("who_disagrees", _params, socket) do
    send_action_to_parent(socket, :who_disagrees)
    {:noreply, assign(socket, visible: false)}
  end

  @impl true
  def handle_event("analogy", _params, socket) do
    send_action_to_parent(socket, :analogy)
    {:noreply, assign(socket, visible: false)}
  end

  @impl true
  def handle_event("what_if", _params, socket) do
    send_action_to_parent(socket, :what_if)
    {:noreply, assign(socket, visible: false)}
  end

  @impl true
  def handle_event("deepdive", _params, socket) do
    send_action_to_parent(socket, :deepdive)
    {:noreply, assign(socket, visible: false)}
  end

  @impl true
  def handle_event("toggle_ask_question", _params, socket) do
    {:noreply, update(socket, :ask_question, &(!&1))}
  end

  @impl true
  def handle_event("toggle_advanced_tools", _params, socket) do
    {:noreply, update(socket, :show_advanced_tools, &(!&1))}
  end

  @impl true
  def handle_event("submit_input", %{"question" => content}, socket) do
    if socket.assigns.ask_question do
      send_action_to_parent(socket, :ask_question, %{question: content})
    else
      send_action_to_parent(socket, :comment, %{comment: content})
    end

    {:noreply, assign(socket, visible: false)}
  end

  defp send_action_to_parent(socket, action, extra_params \\ %{}) do
    params =
      Map.merge(
        %{
          action: action,
          selected_text: socket.assigns.selected_text,
          node_id: socket.assigns.node_id,
          offsets: socket.assigns.offsets,
          highlight: socket.assigns.highlight
        },
        extra_params
      )

    send(self(), {:selection_action, params})
  end

  defp has_link_type?(links, type) do
    Enum.any?(links, fn link -> link.link_type == type end)
  end

  defp count_link_type(links, type) do
    Enum.count(links, fn link -> link.link_type == type end)
  end

  defp has_pros_or_cons?(links) do
    has_link_type?(links, "pro") || has_link_type?(links, "con")
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id}>
      <div
        id={"selection-actions-modal-#{@id}"}
        class={if @visible, do: "", else: "hidden"}
        phx-target={@myself}
      >
        <!-- Modal backdrop -->
        <div
          phx-click="close"
          phx-target={@myself}
          class="fixed inset-0 bg-gray-900/50 backdrop-blur-sm z-[999] transition-opacity duration-200"
        >
        </div>
        <!-- Modal content -->
        <div class="fixed top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 bg-white shadow-2xl rounded-xl p-4 sm:p-6 z-[1000] border border-gray-200 flex flex-col gap-3 w-[90vw] max-w-[500px] max-h-[90vh] overflow-y-auto transition-all duration-200 opacity-100 scale-100">
          <%!-- Header with close button --%>
          <div class="flex items-center justify-between mb-2">
            <h3 class="text-lg font-semibold text-gray-900">Selection Actions</h3>
            <button
              type="button"
              phx-click="close"
              phx-target={@myself}
              class="text-gray-400 hover:text-gray-600 p-2 rounded-full hover:bg-gray-100 transition-colors"
            >
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="h-5 w-5"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M6 18L18 6M6 6l12 12"
                />
              </svg>
            </button>
          </div>
          <%!-- Selected text display --%>
          <div class="p-4 bg-gradient-to-br from-indigo-50 to-blue-50 rounded-lg border border-indigo-200 shadow-sm">
            <div class="text-xs text-indigo-700 mb-2 font-semibold uppercase tracking-wide">
              Selected text:
            </div>
            <div class="text-base text-gray-900 font-medium leading-relaxed max-h-32 overflow-y-auto">
              {@selected_text}
            </div>
          </div>
          <%!-- Action buttons grid --%>
          <div class="grid grid-cols-2 gap-3">
            <%!-- Explain Button --%>
            <button
              type="button"
              phx-click="explain"
              phx-target={@myself}
              disabled={!@can_edit || has_link_type?(@links, "explain")}
              title={
                if has_link_type?(@links, "explain"),
                  do: "Explanation already exists for this text",
                  else: "Create an AI explanation"
              }
              class="bg-blue-500 hover:bg-blue-600 text-white text-sm py-2.5 px-4 rounded-lg flex items-center justify-center transition-all hover:shadow-lg font-medium disabled:opacity-50 disabled:cursor-not-allowed"
            >
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="h-5 w-5 mr-1.5"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
                stroke-width="2.5"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M9.879 7.519c1.171-1.025 3.071-1.025 4.242 0 1.172 1.025 1.172 2.687 0 3.712-.203.179-.43.326-.67.442-.745.361-1.45.999-1.45 1.827v.75M21 12a9 9 0 11-18 0 9 9 0 0118 0zm-9 5.25h.008v.008H12v-.008z"
                />
              </svg>
              <%= if has_link_type?(@links, "explain") do %>
                View Explanation
              <% else %>
                Explain
              <% end %>
            </button>
            <%!-- Highlight Only Button --%>
            <button
              type="button"
              phx-click="highlight_only"
              phx-target={@myself}
              disabled={!@can_edit || !is_nil(@highlight)}
              title={
                if !is_nil(@highlight),
                  do: "Highlight already exists for this selection",
                  else: "Save this text selection as a highlight"
              }
              class="bg-yellow-400 hover:bg-yellow-500 text-gray-900 text-sm py-2.5 px-4 rounded-lg flex items-center justify-center transition-all hover:shadow-lg font-medium disabled:opacity-50 disabled:cursor-not-allowed"
            >
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="h-4 w-4 mr-1.5"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"
                />
              </svg>
              Highlight
            </button>
            <%!-- Pros/Cons Button --%>
            <button
              type="button"
              phx-click="pros_cons"
              phx-target={@myself}
              disabled={!@can_edit || has_pros_or_cons?(@links)}
              title={
                if has_pros_or_cons?(@links),
                  do: "Pros/Cons already exist for this text",
                  else: "Analyze pros and cons"
              }
              class="bg-gradient-to-r from-emerald-500 to-rose-500 hover:from-emerald-600 hover:to-rose-600 text-white text-sm py-2.5 px-4 rounded-lg flex items-center justify-center transition-all hover:shadow-lg font-medium disabled:opacity-50 disabled:cursor-not-allowed"
            >
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="h-5 w-5 mr-1.5"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M7.217 10.907a2.25 2.25 0 1 0 0 2.186m0-2.186c.18.324.283.696.283 1.093s-.103.77-.283 1.093m0-2.186 9.566-5.314m-9.566 7.5 9.566 5.314m0 0a2.25 2.25 0 1 0 3.935 2.186 2.25 2.25 0 0 0-3.935-2.186Zm0-12.814a2.25 2.25 0 1 0 3.933-2.185 2.25 2.25 0 0 0-3.933 2.185Z"
                />
              </svg>
              <%= if has_pros_or_cons?(@links) do %>
                View Pros/Cons
              <% else %>
                Pros & Cons
              <% end %>
            </button>
            <%!-- Related Ideas Button --%>
            <button
              type="button"
              phx-click="related_ideas"
              phx-target={@myself}
              disabled={!@can_edit || has_link_type?(@links, "related_idea")}
              title={
                if has_link_type?(@links, "related_idea"),
                  do: "Related ideas already exist for this text",
                  else: "Find related ideas"
              }
              class="bg-orange-500 hover:bg-orange-600 text-white text-sm py-2.5 px-4 rounded-lg flex items-center justify-center transition-all hover:shadow-lg font-medium disabled:opacity-50 disabled:cursor-not-allowed"
            >
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="h-5 w-5 mr-1.5"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M12 18v-5.25m0 0a6.01 6.01 0 0 0 1.5-.189m-1.5.189a6.01 6.01 0 0 1-1.5-.189m3.75 7.478a12.06 12.06 0 0 1-4.5 0m3.75 2.383a14.406 14.406 0 0 1-3 0M14.25 18v-.192c0-.983.658-1.823 1.508-2.316a7.5 7.5 0 1 0-7.517 0c.85.493 1.509 1.333 1.509 2.316V18"
                />
              </svg>
              <%= if has_link_type?(@links, "related_idea") do %>
                <%= if count_link_type(@links, "related_idea") > 1 do %>
                  View Ideas ({count_link_type(@links, "related_idea")})
                <% else %>
                  View Related Idea
                <% end %>
              <% else %>
                Related Ideas
              <% end %>
            </button>
          </div>
          <%!-- Advanced Critical Thinking Tools (Collapsible) --%>
          <div class="border-t border-gray-200 pt-3 mt-1">
            <button
              type="button"
              phx-click="toggle_advanced_tools"
              phx-target={@myself}
              class="w-full flex items-center justify-between gap-2 px-3 py-2 text-left rounded-lg transition hover:bg-gray-50"
            >
              <div class="flex items-center gap-2">
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  class="h-4 w-4 text-indigo-600"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M9.813 15.904 9 18.75l-.813-2.846a4.5 4.5 0 0 0-3.09-3.09L2.25 12l2.846-.813a4.5 4.5 0 0 0 3.09-3.09L9 5.25l.813 2.846a4.5 4.5 0 0 0 3.09 3.09L15.75 12l-2.846.813a4.5 4.5 0 0 0-3.09 3.09ZM18.259 8.715 18 9.75l-.259-1.035a3.375 3.375 0 0 0-2.455-2.456L14.25 6l1.036-.259a3.375 3.375 0 0 0 2.455-2.456L18 2.25l.259 1.035a3.375 3.375 0 0 0 2.456 2.456L21.75 6l-1.035.259a3.375 3.375 0 0 0-2.456 2.456ZM16.894 20.567 16.5 21.75l-.394-1.183a2.25 2.25 0 0 0-1.423-1.423L13.5 18.75l1.183-.394a2.25 2.25 0 0 0 1.423-1.423l.394-1.183.394 1.183a2.25 2.25 0 0 0 1.423 1.423l1.183.394-1.183.394a2.25 2.25 0 0 0-1.423 1.423Z"
                  />
                </svg>
                <span class="text-sm font-medium text-gray-700">Advanced Critical Thinking</span>
              </div>
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class={[
                  "h-5 w-5 text-gray-400 transition-transform",
                  if(@show_advanced_tools, do: "rotate-180", else: "")
                ]}
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M19 9l-7 7-7-7"
                />
              </svg>
            </button>

            <div class={[
              "mt-2 space-y-3",
              if(!@show_advanced_tools, do: "hidden", else: "")
            ]}>
              <%!-- Core Analysis --%>
              <div>
                <h5 class="text-xs font-semibold uppercase tracking-wider text-gray-500 mb-1.5 px-1">
                  Core Analysis
                </h5>
                <div class="grid grid-cols-2 gap-2">
                  <%!-- Steel Man - First, spans 2 columns --%>
                  <div class="col-span-2">
                    <button
                      type="button"
                      phx-click="steel_man"
                      phx-target={@myself}
                      disabled={!@can_edit}
                      title="Steel Man: Build the strongest version of this argument. Example: If text says 'We should ban cars', the steel man is 'Reduce car dependency in dense urban areas through better transit.'"
                      class={[
                        "flex w-full items-center justify-center rounded-lg border px-4 py-2.5 text-sm font-semibold text-slate-800 transition-all hover:-translate-y-0.5 hover:shadow-md disabled:opacity-50 disabled:cursor-not-allowed",
                        ColUtils.advanced_tool_surface_class("steel_man")
                      ]}
                    >
                      <svg
                        xmlns="http://www.w3.org/2000/svg"
                        class={[
                          "mr-1.5 h-5 w-5",
                          ColUtils.advanced_tool_text_class("steel_man")
                        ]}
                        viewBox="0 0 24 24"
                        fill="none"
                        stroke="currentColor"
                        stroke-width="2.5"
                      >
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          d="M11.48 3.499a.562.562 0 0 1 1.04 0l2.125 5.111a.563.563 0 0 0 .475.345l5.518.442c.499.04.701.663.321.988l-4.204 3.602a.563.563 0 0 0-.182.557l1.285 5.385a.562.562 0 0 1-.84.61l-4.725-2.885a.562.562 0 0 0-.586 0L6.982 20.54a.562.562 0 0 1-.84-.61l1.285-5.386a.562.562 0 0 0-.182-.557l-4.204-3.602a.562.562 0 0 1 .321-.988l5.518-.442a.563.563 0 0 0 .475-.345L11.48 3.5Z"
                        />
                      </svg>
                      Steel Man
                    </button>
                  </div>

                  <%!-- Assumptions --%>
                  <button
                    type="button"
                    phx-click="assumptions"
                    phx-target={@myself}
                    disabled={!@can_edit}
                    title="Assumptions: Reveal what must be true for this claim to work."
                    class={[
                      "flex items-center justify-center rounded-lg border px-3 py-2 text-xs font-medium text-slate-800 transition-all hover:-translate-y-0.5 hover:shadow-md disabled:opacity-50 disabled:cursor-not-allowed",
                      ColUtils.advanced_tool_button_class("assumptions")
                    ]}
                  >
                    <svg
                      xmlns="http://www.w3.org/2000/svg"
                      class={[
                        "mr-1 h-4 w-4",
                        ColUtils.advanced_tool_text_class("assumptions")
                      ]}
                      fill="none"
                      viewBox="0 0 24 24"
                      stroke="currentColor"
                      stroke-width="2"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        d="M21 7.5l-2.25-1.313M21 7.5v2.25m0-2.25l-2.25 1.313M3 7.5l2.25-1.313M3 7.5l2.25 1.313M3 7.5v2.25m9 3l2.25-1.313M12 12.75l-2.25-1.313M12 12.75V15m0 6.75l2.25-1.313M12 21.75V19.5m0 2.25l-2.25-1.313m0-16.875L12 2.25l2.25 1.313M21 14.25v2.25l-2.25 1.313m-13.5 0L3 16.5v-2.25"
                      />
                    </svg>
                    Assumptions
                  </button>

                  <%!-- Test (Counterexample) --%>
                  <button
                    type="button"
                    phx-click="counterexample"
                    phx-target={@myself}
                    disabled={!@can_edit}
                    title="Test: Find counterexamples that challenge this claim."
                    class={[
                      "flex items-center justify-center rounded-lg border px-3 py-2 text-xs font-medium text-slate-800 transition-all hover:-translate-y-0.5 hover:shadow-md disabled:opacity-50 disabled:cursor-not-allowed",
                      ColUtils.advanced_tool_button_class("counterexample")
                    ]}
                  >
                    <svg
                      xmlns="http://www.w3.org/2000/svg"
                      class={[
                        "mr-1 h-4 w-4",
                        ColUtils.advanced_tool_text_class("counterexample")
                      ]}
                      fill="none"
                      viewBox="0 0 24 24"
                      stroke="currentColor"
                      stroke-width="2"
                    >
                      <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
                    </svg>
                    Test
                  </button>
                </div>
              </div>

              <%!-- Critical Evaluation --%>
              <div>
                <h5 class="text-xs font-semibold uppercase tracking-wider text-gray-500 mb-1.5 px-1">
                  Critical Evaluation
                </h5>
                <div class="grid grid-cols-2 gap-2">
                  <%!-- Source --%>
                  <button
                    type="button"
                    phx-click="says_who"
                    phx-target={@myself}
                    disabled={!@can_edit}
                    title="Source: Question the authority and evidence behind claims."
                    class={[
                      "flex items-center justify-center rounded-lg border px-3 py-2 text-xs font-medium text-slate-800 transition-all hover:-translate-y-0.5 hover:shadow-md disabled:opacity-50 disabled:cursor-not-allowed",
                      ColUtils.advanced_tool_button_class("says_who")
                    ]}
                  >
                    <svg
                      xmlns="http://www.w3.org/2000/svg"
                      class={[
                        "mr-1 h-4 w-4",
                        ColUtils.advanced_tool_text_class("says_who")
                      ]}
                      fill="none"
                      viewBox="0 0 24 24"
                      stroke="currentColor"
                      stroke-width="2"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        d="M15.75 6a3.75 3.75 0 1 1-7.5 0 3.75 3.75 0 0 1 7.5 0ZM4.501 20.118a7.5 7.5 0 0 1 14.998 0A17.933 17.933 0 0 1 12 21.75c-2.676 0-5.216-.584-7.499-1.632Z"
                      />
                    </svg>
                    Source
                  </button>

                  <%!-- Blind Spots --%>
                  <button
                    type="button"
                    phx-click="blind_spots"
                    phx-target={@myself}
                    disabled={!@can_edit}
                    title="Blind Spots: What perspectives or factors are being overlooked?"
                    class={[
                      "flex items-center justify-center rounded-lg border px-3 py-2 text-xs font-medium text-slate-800 transition-all hover:-translate-y-0.5 hover:shadow-md disabled:opacity-50 disabled:cursor-not-allowed",
                      ColUtils.advanced_tool_button_class("blind_spots")
                    ]}
                  >
                    <svg
                      xmlns="http://www.w3.org/2000/svg"
                      class={[
                        "mr-1 h-4 w-4",
                        ColUtils.advanced_tool_text_class("blind_spots")
                      ]}
                      fill="none"
                      viewBox="0 0 24 24"
                      stroke="currentColor"
                      stroke-width="2"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        d="M3.98 8.223A10.477 10.477 0 0 0 1.934 12C3.226 16.338 7.244 19.5 12 19.5c.993 0 1.953-.138 2.863-.395M6.228 6.228A10.451 10.451 0 0 1 12 4.5c4.756 0 8.773 3.162 10.065 7.498a10.522 10.522 0 0 1-4.293 5.774M6.228 6.228 3 3m3.228 3.228 3.65 3.65m7.894 7.894L21 21m-3.228-3.228-3.65-3.65m0 0a3 3 0 1 0-4.243-4.243m4.242 4.242L9.88 9.88"
                      />
                    </svg>
                    Blind Spots
                  </button>

                  <%!-- Who Disagrees --%>
                  <button
                    type="button"
                    phx-click="who_disagrees"
                    phx-target={@myself}
                    disabled={!@can_edit}
                    title="Who Disagrees: Explore different perspectives and opposing viewpoints."
                    class={[
                      "flex items-center justify-center rounded-lg border px-3 py-2 text-xs font-medium text-slate-800 transition-all hover:-translate-y-0.5 hover:shadow-md disabled:opacity-50 disabled:cursor-not-allowed",
                      ColUtils.advanced_tool_button_class("who_disagrees")
                    ]}
                  >
                    <svg
                      xmlns="http://www.w3.org/2000/svg"
                      class={[
                        "mr-1 h-4 w-4",
                        ColUtils.advanced_tool_text_class("who_disagrees")
                      ]}
                      fill="none"
                      viewBox="0 0 24 24"
                      stroke="currentColor"
                      stroke-width="2"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        d="M18 18.72a9.094 9.094 0 0 0 3.741-.479 3 3 0 0 0-4.682-2.72m.94 3.198.001.031c0 .225-.012.447-.037.666A11.944 11.944 0 0 1 12 21c-2.17 0-4.207-.576-5.963-1.584A6.062 6.062 0 0 1 6 18.719m12 0a5.971 5.971 0 0 0-.941-3.197m0 0A5.995 5.995 0 0 0 12 12.75a5.995 5.995 0 0 0-5.058 2.772m0 0a3 3 0 0 0-4.681 2.72 8.986 8.986 0 0 0 3.74.477m.94-3.197a5.971 5.971 0 0 0-.94 3.197M15 6.75a3 3 0 1 1-6 0 3 3 0 0 1 6 0Zm6 3a2.25 2.25 0 1 1-4.5 0 2.25 2.25 0 0 1 4.5 0Zm-13.5 0a2.25 2.25 0 1 1-4.5 0 2.25 2.25 0 0 1 4.5 0Z"
                      />
                    </svg>
                    Who Disagrees
                  </button>
                </div>
              </div>

              <%!-- Implications & Consequences --%>
              <div>
                <h5 class="text-xs font-semibold uppercase tracking-wider text-gray-500 mb-1.5 px-1">
                  Implications & Consequences
                </h5>
                <div class="grid grid-cols-2 gap-2">
                  <%!-- Implications --%>
                  <button
                    type="button"
                    phx-click="implications"
                    phx-target={@myself}
                    disabled={!@can_edit}
                    title="Implications: What would happen if this were true?"
                    class={[
                      "flex items-center justify-center rounded-lg border px-3 py-2 text-xs font-medium text-slate-800 transition-all hover:-translate-y-0.5 hover:shadow-md disabled:opacity-50 disabled:cursor-not-allowed",
                      ColUtils.advanced_tool_button_class("implications")
                    ]}
                  >
                    <svg
                      xmlns="http://www.w3.org/2000/svg"
                      class={[
                        "mr-1 h-4 w-4",
                        ColUtils.advanced_tool_text_class("implications")
                      ]}
                      fill="none"
                      viewBox="0 0 24 24"
                      stroke="currentColor"
                      stroke-width="2"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        d="M2.25 18 9 11.25l4.306 4.306a11.95 11.95 0 0 1 5.814-5.518l2.74-1.22m0 0-5.94-2.281m5.94 2.28-2.28 5.941"
                      />
                    </svg>
                    Implications
                  </button>

                  <%!-- Second Order --%>
                  <button
                    type="button"
                    phx-click="second_order"
                    phx-target={@myself}
                    disabled={!@can_edit}
                    title="Second Order: Explore indirect consequences and ripple effects."
                    class={[
                      "flex items-center justify-center rounded-lg border px-3 py-2 text-xs font-medium text-slate-800 transition-all hover:-translate-y-0.5 hover:shadow-md disabled:opacity-50 disabled:cursor-not-allowed",
                      ColUtils.advanced_tool_button_class("second_order")
                    ]}
                  >
                    <svg
                      xmlns="http://www.w3.org/2000/svg"
                      class={[
                        "mr-1 h-4 w-4",
                        ColUtils.advanced_tool_text_class("second_order")
                      ]}
                      fill="none"
                      viewBox="0 0 24 24"
                      stroke="currentColor"
                      stroke-width="2"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        d="M16.023 9.348h4.992v-.001M2.985 19.644v-4.992m0 0h4.992m-4.993 0 3.181 3.183a8.25 8.25 0 0 0 13.803-3.7M4.031 9.865a8.25 8.25 0 0 1 13.803-3.7l3.181 3.182m0-4.991v4.99"
                      />
                    </svg>
                    Second Order
                  </button>

                  <%!-- What If --%>
                  <button
                    type="button"
                    phx-click="what_if"
                    phx-target={@myself}
                    disabled={!@can_edit}
                    title="What If: Explore hypothetical scenarios and alternative possibilities."
                    class={[
                      "flex items-center justify-center rounded-lg border px-3 py-2 text-xs font-medium text-slate-800 transition-all hover:-translate-y-0.5 hover:shadow-md disabled:opacity-50 disabled:cursor-not-allowed",
                      ColUtils.advanced_tool_button_class("what_if")
                    ]}
                  >
                    <svg
                      xmlns="http://www.w3.org/2000/svg"
                      class={[
                        "mr-1 h-4 w-4",
                        ColUtils.advanced_tool_text_class("what_if")
                      ]}
                      fill="none"
                      viewBox="0 0 24 24"
                      stroke="currentColor"
                      stroke-width="2"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        d="M9.879 7.519c1.171-1.025 3.071-1.025 4.242 0 1.172 1.025 1.172 2.687 0 3.712-.203.179-.43.326-.67.442-.745.361-1.45.999-1.45 1.827v.75M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Zm-9 5.25h.008v.008H12v-.008Z"
                      />
                    </svg>
                    What If
                  </button>
                </div>
              </div>

              <%!-- Understanding & Communication --%>
              <div>
                <h5 class="text-xs font-semibold uppercase tracking-wider text-gray-500 mb-1.5 px-1">
                  Understanding & Communication
                </h5>
                <div class="grid grid-cols-2 gap-2">
                  <%!-- Clarify --%>
                  <button
                    type="button"
                    phx-click="clarify"
                    phx-target={@myself}
                    disabled={!@can_edit}
                    title="Clarify: Make complex ideas clearer."
                    class={[
                      "flex items-center justify-center rounded-lg border px-3 py-2 text-xs font-medium text-slate-800 transition-all hover:-translate-y-0.5 hover:shadow-md disabled:opacity-50 disabled:cursor-not-allowed",
                      ColUtils.advanced_tool_button_class("clarify")
                    ]}
                  >
                    <svg
                      xmlns="http://www.w3.org/2000/svg"
                      class={[
                        "mr-1 h-4 w-4",
                        ColUtils.advanced_tool_text_class("clarify")
                      ]}
                      fill="none"
                      viewBox="0 0 24 24"
                      stroke="currentColor"
                      stroke-width="2"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        d="M12 18v-5.25m0 0a6.01 6.01 0 0 0 1.5-.189m-1.5.189a6.01 6.01 0 0 1-1.5-.189m3.75 7.478a12.06 12.06 0 0 1-4.5 0m3.75 2.383a14.406 14.406 0 0 1-3 0M14.25 18v-.192c0-.983.658-1.823 1.508-2.316a7.5 7.5 0 1 0-7.517 0c.85.493 1.509 1.333 1.509 2.316V18"
                      />
                    </svg>
                    Clarify
                  </button>

                  <%!-- Simplify --%>
                  <button
                    type="button"
                    phx-click="simplify"
                    phx-target={@myself}
                    disabled={!@can_edit}
                    title="Simplify: Break down into plain language anyone can understand."
                    class={[
                      "flex items-center justify-center rounded-lg border px-3 py-2 text-xs font-medium text-slate-800 transition-all hover:-translate-y-0.5 hover:shadow-md disabled:opacity-50 disabled:cursor-not-allowed",
                      ColUtils.advanced_tool_button_class("simplify")
                    ]}
                  >
                    <svg
                      xmlns="http://www.w3.org/2000/svg"
                      class={[
                        "mr-1 h-4 w-4",
                        ColUtils.advanced_tool_text_class("simplify")
                      ]}
                      fill="none"
                      viewBox="0 0 24 24"
                      stroke="currentColor"
                      stroke-width="2"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        d="M9.813 15.904 9 18.75l-.813-2.846a4.5 4.5 0 0 0-3.09-3.09L2.25 12l2.846-.813a4.5 4.5 0 0 0 3.09-3.09L9 5.25l.813 2.846a4.5 4.5 0 0 0 3.09 3.09L15.75 12l-2.846.813a4.5 4.5 0 0 0-3.09 3.09Z"
                      />
                    </svg>
                    Simplify
                  </button>

                  <%!-- Analogy --%>
                  <button
                    type="button"
                    phx-click="analogy"
                    phx-target={@myself}
                    disabled={!@can_edit}
                    title="Analogy: Understand through comparison to familiar concepts."
                    class={[
                      "flex items-center justify-center rounded-lg border px-3 py-2 text-xs font-medium text-slate-800 transition-all hover:-translate-y-0.5 hover:shadow-md disabled:opacity-50 disabled:cursor-not-allowed",
                      ColUtils.advanced_tool_button_class("analogy")
                    ]}
                  >
                    <svg
                      xmlns="http://www.w3.org/2000/svg"
                      class={[
                        "mr-1 h-4 w-4",
                        ColUtils.advanced_tool_text_class("analogy")
                      ]}
                      fill="none"
                      viewBox="0 0 24 24"
                      stroke="currentColor"
                      stroke-width="2"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        d="M7.5 21 3 16.5m0 0L7.5 12M3 16.5h13.5m0-13.5L21 7.5m0 0L16.5 12M21 7.5H7.5"
                      />
                    </svg>
                    Analogy
                  </button>

                  <%!-- Deep Dive - Hidden for now --%>
                  <%!--
                  <button
                    type="button"
                    phx-click="deepdive"
                    phx-target={@myself}
                    disabled={!@can_edit}
                    title="Deep Dive: Explore the topic in greater depth with nuance and context."
                    class="bg-slate-600 hover:bg-slate-700 text-white text-xs py-2 px-3 rounded-lg flex items-center justify-center transition-all hover:shadow-lg font-medium disabled:opacity-50 disabled:cursor-not-allowed"
                  >
                    <svg
                      xmlns="http://www.w3.org/2000/svg"
                      class="h-4 w-4 mr-1"
                      fill="none"
                      viewBox="0 0 24 24"
                      stroke="currentColor"
                      stroke-width="2"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        d="m21 21-5.197-5.197m0 0A7.5 7.5 0 1 0 5.196 5.196a7.5 7.5 0 0 0 10.607 10.607ZM10.5 7.5v6m3-3h-6"
                      />
                    </svg>
                    Deep Dive
                  </button>
                  ---%>
                </div>
              </div>
            </div>
          </div>

          <%!-- Custom question/comment form --%>
          <div class="border-t border-gray-200 pt-3 mt-1">
            <form phx-submit="submit_input" phx-target={@myself} class="flex flex-col gap-2">
              <div class="flex items-center justify-between">
                <label class="text-sm font-medium text-gray-700">
                  <%= if @ask_question do %>
                    Ask a custom question:
                  <% else %>
                    Add a comment:
                  <% end %>
                </label>
                <%!-- Ask/Comment Segmented Control --%>
                <div class="inline-flex rounded-md border border-gray-200 bg-gray-50 flex-none scale-90 origin-right">
                  <button
                    type="button"
                    phx-click="toggle_ask_question"
                    phx-target={@myself}
                    class={[
                      "px-2 py-1 text-xs font-medium transition-all",
                      if @ask_question do
                        "bg-blue-500 text-white rounded-l-md"
                      else
                        "text-gray-600 hover:text-gray-900 hover:bg-gray-100 rounded-l-md"
                      end
                    ]}
                    title="Get an AI-generated response"
                  >
                    Ask
                  </button>
                  <button
                    type="button"
                    phx-click="toggle_ask_question"
                    phx-target={@myself}
                    class={[
                      "px-2 py-1 text-xs font-medium transition-all",
                      if !@ask_question do
                        "bg-emerald-500 text-white rounded-r-md"
                      else
                        "text-gray-600 hover:text-gray-900 hover:bg-gray-100 rounded-r-md"
                      end
                    ]}
                    title="Add your own thought directly"
                  >
                    Comment
                  </button>
                </div>
              </div>

              <div class="flex gap-2 items-start">
                <textarea
                  name="question"
                  rows="1"
                  phx-hook="AutoExpandTextarea"
                  id={"selection-question-input-#{@id}"}
                  class="flex-1 px-3 py-2 text-sm border border-gray-300 rounded-lg focus:border-indigo-500 focus:ring-2 focus:ring-indigo-200 focus:outline-none resize-none min-h-[2.5rem] max-h-[8rem]"
                  placeholder={
                    if @ask_question,
                      do: "What would you like to know?",
                      else: "Add your thought about this selection..."
                  }
                  autocomplete="off"
                  disabled={!@can_edit}
                ></textarea>
                <button
                  type="submit"
                  disabled={!@can_edit}
                  class={[
                    "text-white text-sm py-2 px-4 rounded-lg font-medium transition-all hover:shadow-lg whitespace-nowrap self-start disabled:opacity-50 disabled:cursor-not-allowed",
                    if(@ask_question,
                      do: "bg-indigo-500 hover:bg-indigo-600",
                      else: "bg-emerald-500 hover:bg-emerald-600"
                    )
                  ]}
                >
                  <%= if @ask_question do %>
                    Ask
                  <% else %>
                    Post
                  <% end %>
                </button>
              </div>
              <div class="text-xs text-gray-500 flex items-center justify-between">
                <span>Press Enter to submit • Escape to close</span>
                <div class="flex gap-2">
                  <%= if count_link_type(@links, "question") > 0 do %>
                    <span class="text-indigo-600 font-medium">
                      {count_link_type(@links, "question")} question(s)
                    </span>
                  <% end %>
                  <%= if count_link_type(@links, "comment") > 0 do %>
                    <span class="text-emerald-600 font-medium">
                      {count_link_type(@links, "comment")} comment(s)
                    </span>
                  <% end %>
                </div>
              </div>
            </form>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
