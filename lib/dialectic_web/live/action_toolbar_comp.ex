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

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:inline, fn -> false end)
     |> assign_new(:icons_only, fn -> false end)}
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

        <span class="contents" data-role="reading-tools-group">
          <button
            type="button"
            class={[
              "inline-flex flex-col items-center justify-center gap-0.5 w-14 py-1 shadow-sm ring-1 ring-inset ring-black/10 rounded-md transition-all disabled:opacity-50 disabled:cursor-not-allowed",
              if(noted?,
                do: "bg-yellow-400 text-gray-900 hover:bg-yellow-500 hover:shadow-md",
                else:
                  "bg-gray-100 text-gray-700 hover:bg-yellow-400 hover:text-gray-900 hover:shadow-md"
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
              class="inline-flex flex-col items-center justify-center gap-0.5 w-14 py-1 shadow-sm ring-1 ring-inset ring-black/10 bg-gray-700 text-white rounded-md transition-all hover:bg-gray-800 hover:shadow-md"
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
              class="inline-flex flex-col items-center justify-center gap-0.5 w-14 py-1 shadow-sm ring-1 ring-inset ring-black/10 rounded-md transition-colors opacity-50 cursor-not-allowed bg-gray-300 text-gray-500"
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
            class="inline-flex flex-col items-center justify-center gap-0.5 w-14 py-1 shadow-sm ring-1 ring-inset ring-black/10 bg-indigo-500 text-white rounded-md transition-all hover:bg-indigo-600 hover:shadow-md disabled:opacity-50 disabled:cursor-not-allowed"
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

        <% info = delete_info(assigns) %>
        <span class="contents" data-role="action-buttons-group">
          <button
            type="button"
            class="inline-flex flex-col items-center justify-center gap-0.5 w-14 py-1 shadow-sm ring-1 ring-inset ring-black/10 bg-orange-500 text-white rounded-md transition-all hover:bg-orange-600 hover:shadow-md disabled:opacity-50 disabled:cursor-not-allowed"
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
            class="inline-flex flex-col items-center justify-center gap-0.5 w-14 py-1 shadow-sm ring-1 ring-inset ring-black/10 text-white rounded-md transition-all bg-gradient-to-r from-emerald-500 to-rose-500 hover:from-emerald-600 hover:to-rose-600 hover:shadow-md disabled:opacity-50 disabled:cursor-not-allowed"
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
            class="inline-flex flex-col items-center justify-center gap-0.5 w-14 py-1 shadow-sm ring-1 ring-inset ring-black/10 bg-violet-500 text-white rounded-md transition-all hover:bg-violet-600 hover:shadow-md disabled:opacity-50 disabled:cursor-not-allowed"
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
            id="explore-all-points"
            type="button"
            disabled={is_nil(@graph_id)}
            class="inline-flex flex-col items-center justify-center gap-0.5 w-14 py-1 shadow-sm ring-1 ring-inset ring-black/10 text-white rounded-md transition-all bg-gradient-to-r from-fuchsia-500 via-rose-500 to-amber-500 hover:from-fuchsia-600 hover:via-rose-600 hover:to-amber-600 hover:shadow-md disabled:opacity-50 disabled:cursor-not-allowed"
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
            <span :if={!@icons_only} class="toolbar-label text-[10px] leading-tight font-medium">
              Explore
            </span>
          </button>

          <button
            type="button"
            class="hidden inline-flex flex-col items-center justify-center gap-0.5 w-14 py-1 shadow-sm ring-1 ring-inset ring-black/10 bg-cyan-500 text-white rounded-md transition-all hover:bg-cyan-600 hover:shadow-md disabled:opacity-50 disabled:cursor-not-allowed"
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
              "inline-flex flex-col items-center justify-center gap-0.5 w-14 py-1 shadow-sm ring-1 ring-inset ring-black/10 rounded-md transition-all disabled:opacity-50 disabled:cursor-not-allowed",
              info.deletable && "bg-red-500 text-white hover:bg-red-600 hover:shadow-md",
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

        <span class="contents" data-role="settings-buttons-group">
          <button
            type="button"
            phx-click={
              Phoenix.LiveView.JS.dispatch("toggle-panel",
                to: "#graph-layout",
                detail: %{id: "graph-nav-drawer"}
              )
            }
            class="inline-flex flex-col items-center justify-center gap-0.5 w-14 py-1 shadow-sm ring-1 ring-inset ring-black/10 bg-sky-500 text-white rounded-md transition-all hover:bg-sky-600 hover:shadow-md"
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
            class="inline-flex flex-col items-center justify-center gap-0.5 w-14 py-1 shadow-sm ring-1 ring-inset ring-black/10 bg-amber-500 text-white rounded-md transition-all hover:bg-amber-600 hover:shadow-md"
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
            class="inline-flex flex-col items-center justify-center gap-0.5 w-14 py-1 shadow-sm ring-1 ring-inset ring-black/10 bg-gray-600 text-white rounded-md transition-all hover:bg-gray-700 hover:shadow-md"
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
