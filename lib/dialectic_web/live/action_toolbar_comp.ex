defmodule DialecticWeb.ActionToolbarComp do
  use DialecticWeb, :live_component
  alias DialecticWeb.Utils.UserUtils

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

  @action_btn "inline-flex flex-col items-center justify-center gap-0.5 w-14 py-1 shadow-sm ring-1 ring-inset ring-black/10 rounded-md transition-all hover:shadow-md disabled:opacity-50 disabled:cursor-not-allowed"

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:inline, fn -> false end)
     |> assign_new(:icons_only, fn -> false end)
     |> assign(:action_btn, @action_btn)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <div
        class={
          if @inline,
            do:
              "relative z-10 flex flex-nowrap items-center justify-start gap-1 w-full overflow-x-auto pointer-events-auto",
            else:
              "hidden sm:flex fixed left-1/2 -translate-x-1/2 z-10 bg-white shadow border border-gray-200 px-1.5 py-1 rounded-md items-center justify-center gap-1 pointer-events-auto max-w-[90vw]"
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

        <% noted? = Enum.any?(Map.get(@node || %{}, :noted_by, []), fn u -> u == @user end) %>

        <%!-- ═══════════════════════════════════════════════════════════════ --%>
        <%!-- Reading Tools Group                                           --%>
        <%!-- ═══════════════════════════════════════════════════════════════ --%>
        <span class="contents" data-role="reading-tools-group">
          <button
            type="button"
            class={[
              "#{@action_btn}",
              if(noted?,
                do: "bg-yellow-400 text-gray-900 hover:bg-yellow-500",
                else: "bg-gray-100 text-gray-700 hover:bg-yellow-400 hover:text-gray-900"
              )
            ]}
            phx-click={if noted?, do: "unnote", else: "note"}
            phx-value-node={@node && @node.id}
            disabled={is_nil(@graph_id)}
            title={if noted?, do: "Remove from your notes", else: "Add to your notes"}
            data-role="star-node"
          >
            <%= if noted? do %>
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="h-4 w-4"
                viewBox="0 0 24 24"
                fill="currentColor"
              >
                <path
                  fill-rule="evenodd"
                  d="M10.788 3.21c.448-1.077 1.976-1.077 2.424 0l2.082 5.007 5.404.433c1.164.093 1.636 1.545.749 2.305l-4.117 3.527 1.257 5.273c.271 1.136-.964 2.033-1.96 1.425L12 18.354 7.373 21.18c-.996.608-2.231-.29-1.96-1.425l1.257-5.273-4.117-3.527c-.887-.76-.415-2.212.749-2.305l5.404-.433 2.082-5.006z"
                  clip-rule="evenodd"
                />
              </svg>
            <% else %>
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="h-4 w-4"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M11.049 2.927c.3-.921 1.603-.921 1.902 0l1.519 4.674a1 1 0 00.95.69h4.915c.969 0 1.371 1.24.588 1.81l-3.976 2.888a1 1 0 00-.363 1.118l1.518 4.674c.3.922-.755 1.688-1.538 1.118l-3.976-2.888a1 1 0 00-1.176 0l-3.976 2.888c-.783.57-1.838-.197-1.538-1.118l1.518-4.674a1 1 0 00-.363-1.118l-3.976-2.888c-.784-.57-.38-1.81.588-1.81h4.914a1 1 0 00.951-.69l1.519-4.674z"
                />
              </svg>
            <% end %>
            <span :if={!@icons_only} class="toolbar-label text-[10px] leading-tight font-medium">
              {if noted?, do: "Starred", else: "Star"}
            </span>
          </button>

          <%= if @graph_id do %>
            <.link
              navigate={
                graph_linear_path(
                  @graph_struct,
                  if(@node, do: @node.id, else: nil),
                  if(assigns[:token], do: [token: assigns[:token]], else: [])
                )
              }
              class={"#{@action_btn} bg-gray-700 text-white hover:bg-gray-800"}
              title="Open linear view"
              data-role="reader-view"
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
                  d="M19.5 14.25v-2.625a3.375 3.375 0 0 0-3.375-3.375h-1.5A1.125 1.125 0 0 1 13.5 7.125v-1.5a3.375 3.375 0 0 0-3.375-3.375H8.25m0 12.75h7.5m-7.5 3H12M10.5 2.25H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 0 0-9-9Z"
                />
              </svg>
              <span :if={!@icons_only} class="toolbar-label text-[10px] leading-tight font-medium">
                Read
              </span>
            </.link>
          <% else %>
            <button
              type="button"
              class={"#{@action_btn} opacity-50 cursor-not-allowed bg-gray-300 text-gray-500"}
              disabled
              title="Open reader"
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
                  d="M19.5 14.25v-2.625a3.375 3.375 0 0 0-3.375-3.375h-1.5A1.125 1.125 0 0 1 13.5 7.125v-1.5a3.375 3.375 0 0 0-3.375-3.375H8.25m0 12.75h7.5m-7.5 3H12M10.5 2.25H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 0 0-9-9Z"
                />
              </svg>
              <span :if={!@icons_only} class="toolbar-label text-[10px] leading-tight font-medium">
                Read
              </span>
            </button>
          <% end %>

          <button
            type="button"
            class={"#{@action_btn} bg-indigo-500 text-white hover:bg-indigo-600"}
            phx-click="open_share_modal"
            disabled={is_nil(@graph_id)}
            title="Share graph"
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
                d="M3 16.5v2.25A2.25 2.25 0 0 0 5.25 21h13.5A2.25 2.25 0 0 0 21 18.75V16.5m-13.5-9L12 3m0 0 4.5 4.5M12 3v13.5"
              />
            </svg>
            <span :if={!@icons_only} class="toolbar-label text-[10px] leading-tight font-medium">
              Share
            </span>
          </button>
        </span>

        <div class="toolbar-divider h-8 w-0.5 bg-gray-400 rounded-full flex-none"></div>

        <%!-- ═══════════════════════════════════════════════════════════════ --%>
        <%!-- Original Action Tools                                         --%>
        <%!-- ═══════════════════════════════════════════════════════════════ --%>
        <% info = delete_info(assigns) %>
        <span class="contents" data-role="action-buttons-group">
          <button
            type="button"
            class={"#{@action_btn} bg-orange-500 text-white hover:bg-orange-600"}
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
            <span :if={!@icons_only} class="toolbar-label text-[10px] leading-tight font-medium">
              Ideas
            </span>
          </button>

          <button
            type="button"
            class={"#{@action_btn} text-white bg-gradient-to-r from-emerald-500 to-rose-500 hover:from-emerald-600 hover:to-rose-600"}
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
            <span :if={!@icons_only} class="toolbar-label text-[10px] leading-tight font-medium">
              Pro/Con
            </span>
          </button>

          <button
            type="button"
            class={"#{@action_btn} bg-violet-500 text-white hover:bg-violet-600"}
            phx-click="node_combine"
            phx-value-id={@node && @node.id}
            disabled={is_nil(@graph_id)}
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
            <span :if={!@icons_only} class="toolbar-label text-[10px] leading-tight font-medium">
              Blend
            </span>
          </button>

          <button
            type="button"
            class={"#{@action_btn} hidden bg-cyan-500 text-white hover:bg-cyan-600"}
            phx-click="node_deepdive"
            phx-value-id={@node && @node.id}
            disabled={is_nil(@graph_id)}
            title="Deep dive"
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
              <circle cx="11" cy="11" r="7" />
              <path d="M21 21l-4.35-4.35" />
              <path d="M11 8v6M8 11h6" />
            </svg>
            <span :if={!@icons_only} class="toolbar-label text-[10px] leading-tight font-medium">
              Deep Dive
            </span>
          </button>
        </span>

        <div class="toolbar-divider h-8 w-0.5 bg-gray-400 rounded-full flex-none"></div>

        <%!-- ═══════════════════════════════════════════════════════════════ --%>
        <%!-- Cluster 1 — Core Inquiry Moves                               --%>
        <%!-- Clarify → Assume → Test → So What → Gaps                     --%>
        <%!-- ═══════════════════════════════════════════════════════════════ --%>
        <span class="contents" data-role="inquiry-core-group">
          <%!-- Clarify — "What do you mean by…?" --%>
          <button
            type="button"
            class={"#{@action_btn} bg-teal-500 text-white hover:bg-teal-600"}
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
            <span :if={!@icons_only} class="toolbar-label text-[10px] leading-tight font-medium">
              Clarify
            </span>
          </button>

          <%!-- Assume — "What has to be true?" --%>
          <button
            type="button"
            class={"#{@action_btn} bg-amber-500 text-white hover:bg-amber-600"}
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
            <span :if={!@icons_only} class="toolbar-label text-[10px] leading-tight font-medium">
              Assume
            </span>
          </button>

          <%!-- Test — "Is that always true?" --%>
          <button
            type="button"
            class={"#{@action_btn} bg-red-500 text-white hover:bg-red-600"}
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
            <span :if={!@icons_only} class="toolbar-label text-[10px] leading-tight font-medium">
              Test
            </span>
          </button>

          <%!-- So What — Trace consequences --%>
          <button
            type="button"
            class={"#{@action_btn} bg-indigo-500 text-white hover:bg-indigo-600"}
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
            <span :if={!@icons_only} class="toolbar-label text-[10px] leading-tight font-medium">
              So What
            </span>
          </button>

          <%!-- Gaps — "What's missing?" --%>
          <button
            type="button"
            class={"#{@action_btn} bg-purple-500 text-white hover:bg-purple-600"}
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
            <span :if={!@icons_only} class="toolbar-label text-[10px] leading-tight font-medium">
              Gaps
            </span>
          </button>
        </span>

        <div class="toolbar-divider h-8 w-0.5 bg-gray-400 rounded-full flex-none"></div>

        <%!-- ═══════════════════════════════════════════════════════════════ --%>
        <%!-- Cluster 2 — Context & Dialectical Expansion                   --%>
        <%!-- Source → Disagree → Analogy → Steel Man → What If             --%>
        <%!-- ═══════════════════════════════════════════════════════════════ --%>
        <span class="contents" data-role="inquiry-context-group">
          <%!-- Source — "Says who?" --%>
          <button
            type="button"
            class={"#{@action_btn} bg-sky-500 text-white hover:bg-sky-600"}
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
              <path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20" />
              <path d="M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2z" />
            </svg>
            <span :if={!@icons_only} class="toolbar-label text-[10px] leading-tight font-medium">
              Source
            </span>
          </button>

          <%!-- Disagree — "Who would disagree?" --%>
          <button
            type="button"
            class={"#{@action_btn} bg-rose-500 text-white hover:bg-rose-600"}
            phx-click="node_who_disagrees"
            phx-value-id={@node && @node.id}
            disabled={is_nil(@graph_id)}
            title="Who would disagree? — Challenge from other perspectives"
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
            <span :if={!@icons_only} class="toolbar-label text-[10px] leading-tight font-medium">
              Disagree
            </span>
          </button>

          <%!-- Analogy — "What is this like?" --%>
          <button
            type="button"
            class={"#{@action_btn} bg-emerald-500 text-white hover:bg-emerald-600"}
            phx-click="node_analogy"
            phx-value-id={@node && @node.id}
            disabled={is_nil(@graph_id)}
            title="What is this like? — Find illuminating analogies"
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
              <path d="M8.12 8.12L15.88 15.88" />
            </svg>
            <span :if={!@icons_only} class="toolbar-label text-[10px] leading-tight font-medium">
              Analogy
            </span>
          </button>

          <%!-- Steel Man — charitable reconstruction --%>
          <button
            type="button"
            class={"#{@action_btn} bg-yellow-500 text-white hover:bg-yellow-600"}
            phx-click="node_steel_man"
            phx-value-id={@node && @node.id}
            disabled={is_nil(@graph_id)}
            title="Steel man this — Strongest opposing argument"
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
              <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" />
            </svg>
            <span :if={!@icons_only} class="toolbar-label text-[10px] leading-tight font-medium">
              Steel Man
            </span>
          </button>

          <%!-- What If — thought experiments --%>
          <button
            type="button"
            class={"#{@action_btn} bg-fuchsia-500 text-white hover:bg-fuchsia-600"}
            phx-click="node_what_if"
            phx-value-id={@node && @node.id}
            disabled={is_nil(@graph_id)}
            title="What if…? — Thought experiments and scenarios"
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
              <polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2" />
            </svg>
            <span :if={!@icons_only} class="toolbar-label text-[10px] leading-tight font-medium">
              What If
            </span>
          </button>
        </span>

        <div class="toolbar-divider h-8 w-0.5 bg-gray-400 rounded-full flex-none"></div>

        <%!-- ═══════════════════════════════════════════════════════════════ --%>
        <%!-- Cluster 3 — Clarity + Delete                                  --%>
        <%!-- ═══════════════════════════════════════════════════════════════ --%>
        <span class="contents" data-role="inquiry-clarity-group">
          <%!-- Simplify — "Rewrite for a 10-year-old" --%>
          <button
            type="button"
            class={"#{@action_btn} bg-orange-400 text-white hover:bg-orange-500"}
            phx-click="node_simplify"
            phx-value-id={@node && @node.id}
            disabled={is_nil(@graph_id)}
            title="Rewrite for a 10-year-old — Clarity test"
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
              <path d="M8 14s1.5 2 4 2 4-2 4-2" />
              <line x1="9" y1="9" x2="9.01" y2="9" />
              <line x1="15" y1="9" x2="15.01" y2="9" />
            </svg>
            <span :if={!@icons_only} class="toolbar-label text-[10px] leading-tight font-medium">
              Simplify
            </span>
          </button>

          <%!-- Delete node --%>
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
              @action_btn,
              info.deletable && "bg-red-500 text-white hover:bg-red-600",
              !info.deletable && "bg-gray-200 text-gray-400 cursor-not-allowed"
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
            <span :if={!@icons_only} class="toolbar-label text-[10px] leading-tight font-medium">
              Delete
            </span>
          </button>
        </span>

        <div class="toolbar-divider h-8 w-0.5 bg-gray-400 rounded-full flex-none"></div>

        <%!-- ═══════════════════════════════════════════════════════════════ --%>
        <%!-- Settings Group                                                --%>
        <%!-- ═══════════════════════════════════════════════════════════════ --%>
        <span class="contents" data-role="settings-buttons-group">
          <button
            type="button"
            phx-click={
              Phoenix.LiveView.JS.dispatch("toggle-panel",
                to: "#graph-layout",
                detail: %{id: "graph-nav-drawer"}
              )
            }
            class={"#{@action_btn} bg-sky-500 text-white hover:bg-sky-600"}
            data-panel-toggle="graph-nav-drawer"
            aria-label="Toggle view options"
            title="View Options"
          >
            <.icon name="hero-eye" class="w-4 h-4" />
            <span :if={!@icons_only} class="toolbar-label text-[10px] leading-tight font-medium">
              Views
            </span>
          </button>
          <button
            type="button"
            phx-click={
              Phoenix.LiveView.JS.dispatch("toggle-panel",
                to: "#graph-layout",
                detail: %{id: "highlights-drawer"}
              )
            }
            class={"#{@action_btn} bg-amber-500 text-white hover:bg-amber-600"}
            data-panel-toggle="highlights-drawer"
            aria-label="Toggle highlights"
            title="Highlights"
          >
            <.icon name="hero-bookmark" class="w-4 h-4" />
            <span :if={!@icons_only} class="toolbar-label text-[10px] leading-tight font-medium">
              Highlights
            </span>
          </button>
          <button
            type="button"
            phx-click={
              Phoenix.LiveView.JS.dispatch("toggle-panel",
                to: "#graph-layout",
                detail: %{id: "right-panel"}
              )
            }
            class={"#{@action_btn} bg-gray-600 text-white hover:bg-gray-700"}
            data-panel-toggle="right-panel"
            aria-label="Toggle settings"
            title="Settings"
          >
            <.icon name="hero-adjustments-horizontal" class="w-4 h-4" />
            <span :if={!@icons_only} class="toolbar-label text-[10px] leading-tight font-medium">
              Settings
            </span>
          </button>
        </span>
      </div>
    </div>
    """
  end
end
