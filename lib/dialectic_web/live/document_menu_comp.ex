defmodule DialecticWeb.DocumentMenuComp do
  use DialecticWeb, :live_component

  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  # Ensure we show at least 2 nodes when starting from node 1
  # so users don't think the document view is broken
  defp get_document_start_node(nil), do: nil
  defp get_document_start_node(%{id: "1"}), do: "2"
  defp get_document_start_node(%{id: id}), do: id

  def render(assigns) do
    ~H"""
    <div
      class="fixed top-14 right-2 md:right-3 lg:right-4 z-40 w-72 xl:w-[14rem] max-w-[calc(100vw-0.75rem)]"
      data-role="document-menu"
    >
      <div class="rounded-xl border border-gray-200 bg-white/95 backdrop-blur-md shadow-lg p-2 space-y-2">
        <button
          type="button"
          phx-click="open_search_overlay_click"
          class="flex items-center gap-2 w-full px-3 py-2 bg-gray-50 border border-gray-200 text-gray-500 hover:text-gray-700 hover:bg-gray-100 transition-colors rounded-lg group"
          title="Quick search (⌘K)"
        >
          <.icon name="hero-magnifying-glass" class="w-4 h-4 shrink-0" />
          <span class="text-xs">Search topics...</span>
          <kbd class="ml-auto inline-flex items-center rounded border border-gray-300 bg-white px-1 py-0.5 text-[9px] font-semibold text-gray-500 leading-none">
            ⌘K
          </kbd>
        </button>
        <p class="px-1 text-[11px] text-gray-500">
          Search all nodes and jump directly to the relevant part of the discussion.
        </p>

        <div class="grid grid-cols-2 gap-1">
          <%= if @graph_id do %>
            <.link
              navigate={
                graph_linear_path(
                  @graph_struct,
                  get_document_start_node(assigns[:node]),
                  if(assigns[:token], do: [token: assigns[:token]], else: [])
                )
              }
              class="group flex h-12 flex-col items-start justify-center rounded-md border border-blue-200 bg-blue-50 px-2 text-left transition-colors hover:bg-blue-100"
              title="Open document view"
              data-role="reader-view"
            >
              <span class="inline-flex items-center gap-1 text-[11px] font-semibold text-blue-700">
                <.icon name="hero-document-text" class="w-3 h-3" /> Doc
              </span>
              <span class="text-[9px] leading-tight text-blue-600/90">Reader view</span>
            </.link>
          <% else %>
            <span class="flex h-12 flex-col items-start justify-center rounded-md border border-blue-100 bg-blue-50/70 px-2 text-left">
              <span class="inline-flex items-center gap-1 text-[11px] font-semibold text-blue-500">
                Doc
              </span>
              <span class="text-[9px] leading-tight text-blue-400">Reader view</span>
            </span>
          <% end %>

          <button
            type="button"
            class="group flex h-12 flex-col items-start justify-center rounded-md border border-indigo-200 bg-indigo-50 px-2 text-left transition-colors hover:bg-indigo-100 disabled:opacity-50 disabled:cursor-not-allowed"
            phx-click="open_share_modal"
            disabled={is_nil(@graph_id)}
            title="Share graph"
          >
            <span class="inline-flex items-center gap-1 text-[11px] font-semibold text-indigo-700">
              <.icon name="hero-share" class="w-3 h-3" /> Share
            </span>
            <span class="text-[9px] leading-tight text-indigo-600/90">Links and access</span>
          </button>

          <button
            type="button"
            phx-click={
              Phoenix.LiveView.JS.dispatch("toggle-panel",
                to: "#graph-layout",
                detail: %{id: "presentation-drawer"}
              )
              |> Phoenix.LiveView.JS.push("enter_presentation_setup")
            }
            disabled={is_nil(@graph_id)}
            class="group flex h-12 flex-col items-start justify-center rounded-md border border-fuchsia-200 bg-fuchsia-50 px-2 text-left transition-colors hover:bg-fuchsia-100 disabled:opacity-50 disabled:cursor-not-allowed"
            data-panel-toggle="presentation-drawer"
            aria-label="Start presentation setup"
            title="Present"
          >
            <span class="inline-flex items-center gap-1 text-[11px] font-semibold text-fuchsia-700">
              <.icon name="hero-presentation-chart-bar" class="w-3 h-3" /> Present
            </span>
            <span class="text-[9px] leading-tight text-fuchsia-600/90">Slide mode</span>
          </button>

          <button
            type="button"
            phx-click={
              Phoenix.LiveView.JS.dispatch("toggle-panel",
                to: "#graph-layout",
                detail: %{id: "highlights-drawer"}
              )
            }
            class="group flex h-12 flex-col items-start justify-center rounded-md border border-amber-200 bg-amber-50 px-2 text-left transition-colors hover:bg-amber-100"
            data-panel-toggle="highlights-drawer"
            aria-label="Toggle highlights"
            title="Highlights"
          >
            <span class="inline-flex items-center gap-1 text-[11px] font-semibold text-amber-700">
              <.icon name="hero-bookmark" class="w-3 h-3" /> Highlights
            </span>
            <span class="text-[9px] leading-tight text-amber-600/90">Saved excerpts</span>
          </button>
        </div>

        <button
          type="button"
          phx-click={
            Phoenix.LiveView.JS.dispatch("toggle-panel",
              to: "#graph-layout",
              detail: %{id: "right-panel"}
            )
          }
          class="w-full flex items-center justify-between rounded-md border border-gray-200 bg-white px-2.5 py-2 text-gray-700 hover:bg-gray-50 transition-colors"
          data-panel-toggle="right-panel"
          aria-label="Open controls"
          title="Views and settings"
        >
          <span class="inline-flex items-center gap-1.5 text-xs font-semibold text-gray-700">
            <.icon name="hero-adjustments-horizontal" class="w-3.5 h-3.5" /> Controls
          </span>
          <span class="text-[10px] text-gray-500">Views + settings</span>
        </button>

        <%= if @can_edit == false do %>
          <div class="inline-flex items-center gap-1 rounded-md border border-amber-200 bg-amber-100 px-2 py-1 text-[11px] font-semibold text-amber-800">
            <.icon name="hero-lock-closed" class="w-3.5 h-3.5" /> Locked
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
