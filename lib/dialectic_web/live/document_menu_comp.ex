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
    <div class="fixed top-16 right-4 z-40 flex items-center gap-2" data-role="document-menu">
      <%= if @can_edit == false do %>
        <span
          class="inline-flex justify-center items-center gap-1.5 text-xs font-semibold px-3 py-1.5 rounded-full border border-amber-200 bg-amber-50 text-amber-700 shadow-sm"
          title="Graph is locked; editing is disabled"
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            class="h-3.5 w-3.5"
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
          <span class="hidden sm:inline">Locked</span>
        </span>
      <% end %>

      <div class="flex items-center gap-1 bg-white shadow border border-gray-200 rounded-md px-1.5 py-1.5">
        <%= if @graph_id do %>
          <.link
            navigate={
              graph_linear_path(
                @graph_struct,
                get_document_start_node(assigns[:node]),
                if(assigns[:token], do: [token: assigns[:token]], else: [])
              )
            }
            class="inline-flex flex-col items-center justify-center gap-0.5 w-14 py-1 shadow-sm ring-1 ring-inset ring-black/10 bg-blue-600 text-white rounded-md transition-all hover:bg-blue-700 hover:shadow-md"
            title="Open document view"
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
            <span class="toolbar-label text-[10px] leading-tight font-medium">Document</span>
          </.link>
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
          <span class="toolbar-label text-[10px] leading-tight font-medium">Share</span>
        </button>

        <div class="w-px h-6 bg-gray-300"></div>

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
          class="inline-flex flex-col items-center justify-center gap-0.5 w-14 py-1 shadow-sm ring-1 ring-inset ring-black/10 bg-fuchsia-500 text-white rounded-md transition-all hover:bg-fuchsia-600 hover:shadow-md disabled:opacity-50 disabled:cursor-not-allowed"
          data-panel-toggle="presentation-drawer"
          aria-label="Start presentation setup"
          title="Present"
        >
          <.icon name="hero-presentation-chart-bar" class="w-4 h-4" />
          <span class="toolbar-label text-[10px] leading-tight font-medium">Present</span>
        </button>

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
          <span class="toolbar-label text-[10px] leading-tight font-medium">Views</span>
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
          <span class="toolbar-label text-[10px] leading-tight font-medium">Highlights</span>
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
          <span class="toolbar-label text-[10px] leading-tight font-medium">Settings</span>
        </button>
      </div>
    </div>
    """
  end
end
