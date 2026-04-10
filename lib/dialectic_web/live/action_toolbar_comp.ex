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

  ## Optional Assigns
  - `:inline` - Boolean for inline layout (default: false)
  - `:icons_only` - Boolean to show only icons without labels (default: false)
  """

  # Computes deletion constraints and tooltip/title based on assigns
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

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:inline, fn -> false end)
     |> assign_new(:icons_only, fn -> false end)
     |> assign_new(:advanced_tools_open, fn -> false end)}
  end

  @impl true
  def handle_event("toggle_advanced_tools", _, socket) do
    {:noreply, assign(socket, :advanced_tools_open, !socket.assigns.advanced_tools_open)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <div
        class={
          if @inline,
            do: "relative z-10 flex flex-col gap-2 pointer-events-auto",
            else:
              "hidden sm:flex fixed left-1/2 -translate-x-1/2 z-10 bg-white shadow border border-gray-200 px-1.5 py-1 rounded-md flex-col gap-2 pointer-events-auto max-w-[90vw] max-h-[80vh] overflow-y-auto"
        }
        style={unless @inline, do: "bottom: calc(5.5rem + env(safe-area-inset-bottom));"}
        data-external="true"
        data-role="action-toolbar"
      >
        <%= if @can_edit == false do %>
          <span
            class="inline-flex justify-center items-center gap-1.5 text-xs font-semibold px-2 py-0.5 rounded-full border border-amber-200 bg-amber-50 text-amber-700"
            title="Graph is locked; editing is disabled"
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="h-3 w-3"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
              stroke-width="2"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M16 10V8a4 4 0 10-8 0v2m-1 0h10a2 2 0 012 2v6a2 2 0 01-2 2H7a2 2 0 01-2-2v-6a2 2 0 012-2z"
              />
            </svg>
            <span :if={!@icons_only} class="hidden sm:inline">Locked</span>
          </span>
        <% end %>

        <% info = delete_info(assigns) %>
        <%!-- Main Grid Tools Section --%>
        <div data-role="action-buttons-group">
          <div class="text-[10px] font-semibold text-gray-500 uppercase tracking-wide mb-1 text-center">
            Grid Tools
          </div>
          <div class="grid grid-cols-2 gap-1">
            <button
              type="button"
              class="inline-flex flex-row items-center justify-center gap-1 px-2 py-1 shadow-sm ring-1 ring-inset ring-black/10 text-white rounded-md transition-all bg-gradient-to-r from-emerald-500 to-rose-500 hover:from-emerald-600 hover:to-rose-600 hover:shadow-md disabled:opacity-50 disabled:cursor-not-allowed"
              phx-click="node_branch"
              phx-value-id={@node && @node.id}
              disabled={is_nil(@graph_id)}
              title="Pros and Cons"
            >
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="h-4 w-4"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M7.217 10.907a2.25 2.25 0 1 0 0 2.186m0-2.186c.18.324.283.696.283 1.093s-.103.77-.283 1.093m0-2.186 9.566-5.314m-9.566 7.5 9.566 5.314m0 0a2.25 2.25 0 1 0 3.935 2.186 2.25 2.25 0 0 0-3.935-2.186Zm0-12.814a2.25 2.25 0 1 0 3.933-2.185 2.25 2.25 0 0 0-3.933 2.185Z"
                />
              </svg>
              <span :if={!@icons_only} class="toolbar-label text-xs leading-tight font-medium">
                Pro | Con
              </span>
            </button>

            <button
              type="button"
              class="inline-flex flex-row items-center justify-center gap-1 px-2 py-1 shadow-sm ring-1 ring-inset ring-black/10 bg-violet-500 text-white rounded-md transition-all hover:bg-violet-600 hover:shadow-md disabled:opacity-50 disabled:cursor-not-allowed"
              phx-click={
                Phoenix.LiveView.JS.dispatch("toggle-panel",
                  to: "#graph-layout",
                  detail: %{id: "combine-drawer"}
                )
                |> Phoenix.LiveView.JS.push("node_combine")
              }
              disabled={is_nil(@graph_id)}
              data-panel-toggle="combine-drawer"
              aria-label="Combine nodes setup"
              title="Blend with another"
            >
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="h-4 w-4"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M12 3v17.25m0 0c-1.472 0-2.882.265-4.185.75M12 20.25c1.472 0 2.882.265 4.185.75M18.75 4.97A48.416 48.416 0 0 0 12 4.5c-2.291 0-4.545.16-6.75.47m13.5 0c1.01.143 2.01.317 3 .52m-3-.52 2.62 10.726c.122.499-.106 1.028-.589 1.202a5.988 5.988 0 0 1-2.031.352 5.988 5.988 0 0 1-2.031-.352c-.483-.174-.711-.703-.59-1.202L18.75 4.971Zm-16.5.52c.99-.203 1.99-.377 3-.52m0 0 2.62 10.726c.122.499-.106 1.028-.589 1.202a5.989 5.989 0 0 1-2.031.352 5.989 5.989 0 0 1-2.031-.352c-.483-.174-.711-.703-.59-1.202L5.25 4.971Z"
                />
              </svg>
              <span :if={!@icons_only} class="toolbar-label text-xs leading-tight font-medium">
                Blend
              </span>
            </button>

            <button
              type="button"
              class="inline-flex flex-row items-center justify-center gap-1 px-2 py-1 shadow-sm ring-1 ring-inset ring-black/10 bg-orange-500 text-white rounded-md transition-all hover:bg-orange-600 hover:shadow-md disabled:opacity-50 disabled:cursor-not-allowed"
              phx-click="node_related_ideas"
              phx-value-id={@node && @node.id}
              disabled={is_nil(@graph_id)}
              title="Related ideas"
              data-action="related-ideas"
            >
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="h-4 w-4"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M12 18v-5.25m0 0a6.01 6.01 0 0 0 1.5-.189m-1.5.189a6.01 6.01 0 0 1-1.5-.189m3.75 7.478a12.06 12.06 0 0 1-4.5 0m3.75 2.383a14.406 14.406 0 0 1-3 0M14.25 18v-.192c0-.983.658-1.823 1.508-2.316a7.5 7.5 0 1 0-7.517 0c.85.493 1.509 1.333 1.509 2.316V18"
                />
              </svg>
              <span :if={!@icons_only} class="toolbar-label text-xs leading-tight font-medium">
                Related
              </span>
            </button>

            <button
              id="explore-all-points"
              type="button"
              disabled={is_nil(@graph_id)}
              class="inline-flex flex-row items-center justify-center gap-1 px-2 py-1 shadow-sm ring-1 ring-inset ring-black/10 text-white rounded-md transition-all bg-gradient-to-r from-fuchsia-500 via-rose-500 to-amber-500 hover:from-fuchsia-600 hover:via-rose-600 hover:to-amber-600 hover:shadow-md disabled:opacity-50 disabled:cursor-not-allowed"
              title="Explore all points"
            >
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="h-4 w-4"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M9.813 15.904 9 18.75l-.813-2.846a4.5 4.5 0 0 0-3.09-3.09L2.25 12l2.846-.813a4.5 4.5 0 0 0 3.09-3.09L9 5.25l.813 2.846a4.5 4.5 0 0 0 3.09 3.09L15.75 12l-2.846.813a4.5 4.5 0 0 0-3.09 3.09ZM18.259 8.715 18 9.75l-.259-1.035a3.375 3.375 0 0 0-2.455-2.456L14.25 6l1.036-.259a3.375 3.375 0 0 0 2.455-2.456L18 2.25l.259 1.035a3.375 3.375 0 0 0 2.456 2.456L21.75 6l-1.035.259a3.375 3.375 0 0 0-2.456 2.456ZM16.894 20.567 16.5 21.75l-.394-1.183a2.25 2.25 0 0 0-1.423-1.423L13.5 18.75l1.183-.394a2.25 2.25 0 0 0 1.423-1.423l.394-1.183.394 1.183a2.25 2.25 0 0 0 1.423 1.423l1.183.394-1.183.394a2.25 2.25 0 0 0-1.423 1.423Z"
                />
              </svg>
              <span :if={!@icons_only} class="toolbar-label text-xs leading-tight font-medium">
                Explore
              </span>
            </button>
          </div>
        </div>

        <%!-- Advanced Tools Collapsible Section --%>
        <div class="border-t border-gray-200 pt-2" data-role="advanced-tools-section">
          <button
            type="button"
            class="w-full inline-flex items-center justify-between gap-1 px-2 py-1 text-xs font-semibold text-gray-600 hover:text-gray-900 transition-colors"
            phx-click="toggle_advanced_tools"
            phx-target={@myself}
          >
            <span class="uppercase tracking-wide">Advanced Tools</span>
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class={["h-4 w-4 transition-transform", @advanced_tools_open && "rotate-180"]}
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
            >
              <path stroke-linecap="round" stroke-linejoin="round" d="M19 9l-7 7-7-7" />
            </svg>
          </button>

          <div class={["mt-2 space-y-3", !@advanced_tools_open && "hidden"]}>
            <%!-- Cluster 1: Core Inquiry Moves --%>
            <div>
              <div class="text-[9px] font-medium text-gray-400 uppercase tracking-wider mb-1 px-1">
                Core Inquiry
              </div>
              <div class="grid grid-cols-2 gap-1">
                <%!-- Clarify --%>
                <button
                  type="button"
                  class="inline-flex flex-row items-center justify-center gap-1 px-2 py-1 shadow-sm ring-1 ring-inset ring-black/10 bg-teal-500 text-white rounded-md transition-all hover:bg-teal-600 hover:shadow-md disabled:opacity-50 disabled:cursor-not-allowed"
                  phx-click="node_clarify"
                  phx-value-id={@node && @node.id}
                  disabled={is_nil(@graph_id)}
                  title="What do you mean by…? — Conceptual clarification"
                >
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    class="h-4 w-4"
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="2"
                    stroke-linecap="round"
                    stroke-linejoin="round"
                  >
                    <circle cx="12" cy="12" r="10" />
                    <path d="M9.09 9a3 3 0 0 1 5.83 1c0 2-3 3-3 3" />
                    <line x1="12" y1="17" x2="12.01" y2="17" />
                  </svg>
                  <span :if={!@icons_only} class="toolbar-label text-xs leading-tight font-medium">
                    Clarify
                  </span>
                </button>

                <%!-- Assumptions --%>
                <button
                  type="button"
                  class="inline-flex flex-row items-center justify-center gap-1 px-2 py-1 shadow-sm ring-1 ring-inset ring-black/10 bg-amber-500 text-white rounded-md transition-all hover:bg-amber-600 hover:shadow-md disabled:opacity-50 disabled:cursor-not-allowed"
                  phx-click="node_assumptions"
                  phx-value-id={@node && @node.id}
                  disabled={is_nil(@graph_id)}
                  title="What has to be true? — Surface hidden assumptions"
                >
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    class="h-4 w-4"
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="2"
                    stroke-linecap="round"
                    stroke-linejoin="round"
                  >
                    <path d="M12 2L2 7l10 5 10-5-10-5z" />
                    <path d="M2 17l10 5 10-5" />
                    <path d="M2 12l10 5 10-5" />
                  </svg>
                  <span :if={!@icons_only} class="toolbar-label text-xs leading-tight font-medium">
                    Assume
                  </span>
                </button>

                <%!-- Counterexample --%>
                <button
                  type="button"
                  class="inline-flex flex-row items-center justify-center gap-1 px-2 py-1 shadow-sm ring-1 ring-inset ring-black/10 bg-red-500 text-white rounded-md transition-all hover:bg-red-600 hover:shadow-md disabled:opacity-50 disabled:cursor-not-allowed"
                  phx-click="node_counterexample"
                  phx-value-id={@node && @node.id}
                  disabled={is_nil(@graph_id)}
                  title="Is that always true? — Find counterexamples"
                >
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    class="h-4 w-4"
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="2"
                    stroke-linecap="round"
                    stroke-linejoin="round"
                  >
                    <path d="M18 6L6 18" />
                    <path d="M6 6l12 12" />
                  </svg>
                  <span :if={!@icons_only} class="toolbar-label text-xs leading-tight font-medium">
                    Test
                  </span>
                </button>

                <%!-- Implications --%>
                <button
                  type="button"
                  class="inline-flex flex-row items-center justify-center gap-1 px-2 py-1 shadow-sm ring-1 ring-inset ring-black/10 bg-indigo-500 text-white rounded-md transition-all hover:bg-indigo-600 hover:shadow-md disabled:opacity-50 disabled:cursor-not-allowed"
                  phx-click="node_implications"
                  phx-value-id={@node && @node.id}
                  disabled={is_nil(@graph_id)}
                  title="So what? — Trace the consequences"
                >
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    class="h-4 w-4"
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="2"
                    stroke-linecap="round"
                    stroke-linejoin="round"
                  >
                    <line x1="5" y1="12" x2="19" y2="12" />
                    <polyline points="12 5 19 12 12 19" />
                  </svg>
                  <span :if={!@icons_only} class="toolbar-label text-xs leading-tight font-medium">
                    So What
                  </span>
                </button>

                <%!-- Blind Spots --%>
                <button
                  type="button"
                  class="inline-flex flex-row items-center justify-center gap-1 px-2 py-1 shadow-sm ring-1 ring-inset ring-black/10 bg-purple-500 text-white rounded-md transition-all hover:bg-purple-600 hover:shadow-md disabled:opacity-50 disabled:cursor-not-allowed col-span-2"
                  phx-click="node_blind_spots"
                  phx-value-id={@node && @node.id}
                  disabled={is_nil(@graph_id)}
                  title="What's missing? — Detect blind spots"
                >
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    class="h-4 w-4"
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="2"
                    stroke-linecap="round"
                    stroke-linejoin="round"
                  >
                    <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z" />
                    <line x1="1" y1="1" x2="23" y2="23" />
                  </svg>
                  <span :if={!@icons_only} class="toolbar-label text-xs leading-tight font-medium">
                    Blind Spots
                  </span>
                </button>
              </div>
            </div>

            <%!-- Cluster 2: Context & Dialectical Expansion --%>
            <div>
              <div class="text-[9px] font-medium text-gray-400 uppercase tracking-wider mb-1 px-1">
                Context & Expansion
              </div>
              <div class="grid grid-cols-2 gap-1">
                <%!-- Says Who --%>
                <button
                  type="button"
                  class="inline-flex flex-row items-center justify-center gap-1 px-2 py-1 shadow-sm ring-1 ring-inset ring-black/10 bg-sky-500 text-white rounded-md transition-all hover:bg-sky-600 hover:shadow-md disabled:opacity-50 disabled:cursor-not-allowed"
                  phx-click="node_says_who"
                  phx-value-id={@node && @node.id}
                  disabled={is_nil(@graph_id)}
                  title="Says who? — Check sources and authority"
                >
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    class="h-4 w-4"
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="2"
                    stroke-linecap="round"
                    stroke-linejoin="round"
                  >
                    <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2" />
                    <circle cx="12" cy="7" r="4" />
                  </svg>
                  <span :if={!@icons_only} class="toolbar-label text-xs leading-tight font-medium">
                    Source
                  </span>
                </button>

                <%!-- Who Disagrees --%>
                <button
                  type="button"
                  class="inline-flex flex-row items-center justify-center gap-1 px-2 py-1 shadow-sm ring-1 ring-inset ring-black/10 bg-rose-500 text-white rounded-md transition-all hover:bg-rose-600 hover:shadow-md disabled:opacity-50 disabled:cursor-not-allowed"
                  phx-click="node_who_disagrees"
                  phx-value-id={@node && @node.id}
                  disabled={is_nil(@graph_id)}
                  title="Who disagrees? — Map the opposition"
                >
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    class="h-4 w-4"
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="2"
                    stroke-linecap="round"
                    stroke-linejoin="round"
                  >
                    <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" />
                    <circle cx="9" cy="7" r="4" />
                    <path d="M23 21v-2a4 4 0 0 0-3-3.87" />
                    <path d="M16 3.13a4 4 0 0 1 0 7.75" />
                  </svg>
                  <span :if={!@icons_only} class="toolbar-label text-xs leading-tight font-medium">
                    Dissent
                  </span>
                </button>

                <%!-- Analogy --%>
                <button
                  type="button"
                  class="inline-flex flex-row items-center justify-center gap-1 px-2 py-1 shadow-sm ring-1 ring-inset ring-black/10 bg-emerald-500 text-white rounded-md transition-all hover:bg-emerald-600 hover:shadow-md disabled:opacity-50 disabled:cursor-not-allowed"
                  phx-click="node_analogy"
                  phx-value-id={@node && @node.id}
                  disabled={is_nil(@graph_id)}
                  title="What is this like? — Find analogies"
                >
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    class="h-4 w-4"
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="2"
                    stroke-linecap="round"
                    stroke-linejoin="round"
                  >
                    <circle cx="6" cy="6" r="3" />
                    <circle cx="18" cy="18" r="3" />
                    <path d="M8.5 8.5l7 7" />
                  </svg>
                  <span :if={!@icons_only} class="toolbar-label text-xs leading-tight font-medium">
                    Analogy
                  </span>
                </button>

                <%!-- Steel Man --%>
                <button
                  type="button"
                  class="inline-flex flex-row items-center justify-center gap-1 px-2 py-1 shadow-sm ring-1 ring-inset ring-black/10 bg-yellow-500 text-white rounded-md transition-all hover:bg-yellow-600 hover:shadow-md disabled:opacity-50 disabled:cursor-not-allowed"
                  phx-click="node_steel_man"
                  phx-value-id={@node && @node.id}
                  disabled={is_nil(@graph_id)}
                  title="Steel man — Strongest version of the argument"
                >
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    class="h-4 w-4"
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="2"
                    stroke-linecap="round"
                    stroke-linejoin="round"
                  >
                    <path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z" />
                  </svg>
                  <span :if={!@icons_only} class="toolbar-label text-xs leading-tight font-medium">
                    Steel Man
                  </span>
                </button>

                <%!-- What If --%>
                <button
                  type="button"
                  class="inline-flex flex-row items-center justify-center gap-1 px-2 py-1 shadow-sm ring-1 ring-inset ring-black/10 bg-fuchsia-500 text-white rounded-md transition-all hover:bg-fuchsia-600 hover:shadow-md disabled:opacity-50 disabled:cursor-not-allowed col-span-2"
                  phx-click="node_what_if"
                  phx-value-id={@node && @node.id}
                  disabled={is_nil(@graph_id)}
                  title="What if we change X? — Explore counterfactuals"
                >
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    class="h-4 w-4"
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="2"
                    stroke-linecap="round"
                    stroke-linejoin="round"
                  >
                    <path d="M9.59 4.59A2 2 0 1 1 11 8H2m10.59 11.41A2 2 0 1 0 14 16H2m15.73-8.27A2.5 2.5 0 1 1 19.5 12H2" />
                  </svg>
                  <span :if={!@icons_only} class="toolbar-label text-xs leading-tight font-medium">
                    What If?
                  </span>
                </button>
              </div>
            </div>

            <%!-- Cluster 3: Clarity & Communication --%>
            <div>
              <div class="text-[9px] font-medium text-gray-400 uppercase tracking-wider mb-1 px-1">
                Clarity
              </div>
              <div class="grid grid-cols-1 gap-1">
                <%!-- Simplify --%>
                <button
                  type="button"
                  class="inline-flex flex-row items-center justify-center gap-1 px-2 py-1 shadow-sm ring-1 ring-inset ring-black/10 bg-orange-400 text-white rounded-md transition-all hover:bg-orange-500 hover:shadow-md disabled:opacity-50 disabled:cursor-not-allowed"
                  phx-click="node_simplify"
                  phx-value-id={@node && @node.id}
                  disabled={is_nil(@graph_id)}
                  title="Simplify — Make accessible to all"
                >
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    class="h-4 w-4"
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="2"
                    stroke-linecap="round"
                    stroke-linejoin="round"
                  >
                    <path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20" />
                    <path d="M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2z" />
                  </svg>
                  <span :if={!@icons_only} class="toolbar-label text-xs leading-tight font-medium">
                    Simplify
                  </span>
                </button>
              </div>
            </div>
          </div>
        </div>

        <%!-- Delete Action (separate) --%>
        <div class="border-t border-gray-200 pt-2">
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
            class={[
              "w-full inline-flex flex-row items-center justify-center gap-1 px-2 py-1 shadow-sm ring-1 ring-inset ring-black/10 rounded-md transition-all disabled:opacity-50 disabled:cursor-not-allowed",
              info.deletable && "bg-red-500/80 text-white hover:bg-red-600 hover:shadow-md",
              !info.deletable && "bg-gray-100 text-gray-400 cursor-not-allowed"
            ]}
            title={info.title}
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="h-4 w-4"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              stroke-linecap="round"
              stroke-linejoin="round"
            >
              <path d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6M9 7h6m-7 0a1 1 0 01-1-1V5a1 1 0 011-1h2a2 2 0 012-2h0a2 2 0 012 2h2a1 1 0 011 1v1" />
            </svg>
            <span :if={!@icons_only} class="toolbar-label text-xs leading-tight font-medium">
              Delete
            </span>
          </button>
        </div>
      </div>
    </div>
    """
  end
end
