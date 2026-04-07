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
      class="fixed top-14 right-2 md:right-3 lg:right-4 z-40 w-72 xl:w-80 max-w-[calc(100vw-0.75rem)]"
      data-role="document-menu"
    >
      <div class="rounded-xl border border-gray-200 bg-white/95 backdrop-blur-md shadow-lg p-1.5 space-y-1">
        <div class="grid grid-cols-3 gap-1">
          <%= if @graph_id do %>
            <.link
              navigate={
                graph_linear_path(
                  @graph_struct,
                  get_document_start_node(assigns[:node]),
                  if(assigns[:token], do: [token: assigns[:token]], else: [])
                )
              }
              class="inline-flex h-8 items-center justify-center gap-1 rounded-md bg-blue-600 px-2 text-[11px] font-medium text-white hover:bg-blue-700 transition-colors"
              title="Open document view"
              data-role="reader-view"
            >
              <.icon name="hero-document-text" class="w-3.5 h-3.5" /> Doc
            </.link>
          <% else %>
            <span class="inline-flex h-8 items-center justify-center rounded-md bg-blue-100 text-blue-500 text-[11px] font-medium">
              Doc
            </span>
          <% end %>

          <button
            type="button"
            class="inline-flex h-8 items-center justify-center gap-1 rounded-md bg-indigo-500 px-2 text-[11px] font-medium text-white hover:bg-indigo-600 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
            phx-click="open_share_modal"
            disabled={is_nil(@graph_id)}
            title="Share graph"
          >
            <.icon name="hero-share" class="w-3.5 h-3.5" /> Share
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
            class="inline-flex h-8 items-center justify-center gap-1 rounded-md bg-fuchsia-500 px-2 text-[11px] font-medium text-white hover:bg-fuchsia-600 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
            data-panel-toggle="presentation-drawer"
            aria-label="Start presentation setup"
            title="Present"
          >
            <.icon name="hero-presentation-chart-bar" class="w-3.5 h-3.5" /> Present
          </button>
        </div>

        <div class="grid grid-cols-[2fr_1fr_1fr] gap-1">
          <button
            type="button"
            phx-click="open_search_overlay_click"
            class="inline-flex h-8 items-center gap-1.5 rounded-md border border-gray-200 bg-white px-2 text-[11px] font-medium text-gray-700 hover:bg-gray-100 transition-colors"
            title="Quick search (⌘K)"
          >
            <span class="inline-flex items-center gap-1 leading-none">
              <.icon name="hero-magnifying-glass" class="w-3.5 h-3.5" /> Search
            </span>
            <kbd class="hidden sm:inline-flex ml-auto items-center rounded border border-gray-300 bg-gray-50 px-0.5 py-0.5 text-[8px] font-semibold text-gray-500 leading-none">
              ⌘K
            </kbd>
          </button>

          <button
            type="button"
            phx-click={
              Phoenix.LiveView.JS.dispatch("toggle-panel",
                to: "#graph-layout",
                detail: %{id: "graph-nav-drawer"}
              )
            }
            class="inline-flex h-8 items-center justify-center gap-1 rounded-md bg-sky-500 px-2 text-[11px] font-medium text-white hover:bg-sky-600 transition-colors"
            data-panel-toggle="graph-nav-drawer"
            aria-label="Toggle view options"
            title="View options"
          >
            <.icon name="hero-eye" class="w-3.5 h-3.5" /> Views
          </button>

          <button
            type="button"
            phx-click={
              Phoenix.LiveView.JS.dispatch("toggle-panel",
                to: "#graph-layout",
                detail: %{id: "highlights-drawer"}
              )
            }
            class="inline-flex h-8 items-center justify-center gap-1 rounded-md bg-amber-500 px-2 text-[11px] font-medium text-white hover:bg-amber-600 transition-colors"
            data-panel-toggle="highlights-drawer"
            aria-label="Toggle highlights"
            title="Highlights"
          >
            <.icon name="hero-bookmark" class="w-3.5 h-3.5" /> Highlights
          </button>
        </div>

        <div class="flex items-center gap-1">
          <button
            type="button"
            phx-click={
              Phoenix.LiveView.JS.dispatch("toggle-panel",
                to: "#graph-layout",
                detail: %{id: "right-panel"}
              )
            }
            class="inline-flex h-8 flex-1 items-center justify-center gap-1 rounded-md bg-gray-600 px-2 text-[11px] font-medium text-white hover:bg-gray-700 transition-colors"
            data-panel-toggle="right-panel"
            aria-label="Toggle settings"
            title="Settings"
          >
            <.icon name="hero-adjustments-horizontal" class="w-3.5 h-3.5" /> Settings
          </button>

          <%= if @can_edit == false do %>
            <span
              class="inline-flex h-8 items-center justify-center gap-1 rounded-md border border-amber-200 bg-amber-100 px-2 text-[11px] font-semibold text-amber-800"
              title="Graph is locked; editing is disabled"
            >
              <.icon name="hero-lock-closed" class="w-3.5 h-3.5" /> Locked
            </span>
          <% end %>
        </div>
      </div>
    </div>
    """
  end
end
