defmodule DialecticWeb.DocumentMenuComp do
  use DialecticWeb, :live_component

  @impl true
  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div
      class="fixed top-12 right-3 z-30 flex items-center gap-2 pointer-events-auto"
      data-role="document-menu"
    >
      <%= if @can_edit == false do %>
        <span
          class="inline-flex justify-center items-center gap-1.5 text-xs font-semibold px-3 py-1.5 rounded-lg border border-amber-200 bg-amber-50 text-amber-700 shadow-sm"
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
          <span>Locked</span>
        </span>
      <% end %>

      <div class="flex items-center gap-1.5 bg-white/95 backdrop-blur shadow-lg border border-gray-200 rounded-lg px-2 py-1.5">
        <%= if @graph_id do %>
          <.link
            navigate={
              graph_linear_path(
                @graph_struct,
                if(@node, do: @node.id, else: nil),
                if(assigns[:token], do: [token: assigns[:token]], else: [])
              )
            }
            class="inline-flex items-center justify-center gap-1.5 px-3 py-1.5 rounded-md bg-blue-600 text-white transition-all hover:bg-blue-700 text-sm font-medium shadow-sm"
            title="View graph as a linear, readable document"
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
                d="M3.75 6.75h16.5M3.75 12h16.5m-16.5 5.25h16.5"
              />
            </svg>
            <span>Document</span>
          </.link>
        <% end %>

        <button
          type="button"
          class="inline-flex items-center justify-center gap-1.5 px-3 py-1.5 rounded-md bg-indigo-500 text-white transition-all hover:bg-indigo-600 disabled:opacity-50 disabled:cursor-not-allowed text-sm font-medium"
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
          <span>Share</span>
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
          class="inline-flex items-center justify-center p-2 rounded-md bg-fuchsia-500 text-white transition-all hover:bg-fuchsia-600 disabled:opacity-50 disabled:cursor-not-allowed"
          data-panel-toggle="presentation-drawer"
          aria-label="Start presentation setup"
          title="Present"
        >
          <.icon name="hero-presentation-chart-bar" class="w-4 h-4" />
        </button>

        <button
          type="button"
          phx-click={
            Phoenix.LiveView.JS.dispatch("toggle-panel",
              to: "#graph-layout",
              detail: %{id: "graph-nav-drawer"}
            )
          }
          class="inline-flex items-center justify-center p-2 rounded-md bg-sky-500 text-white transition-all hover:bg-sky-600"
          data-panel-toggle="graph-nav-drawer"
          aria-label="Toggle view options"
          title="View Options"
        >
          <.icon name="hero-eye" class="w-4 h-4" />
        </button>

        <button
          type="button"
          phx-click={
            Phoenix.LiveView.JS.dispatch("toggle-panel",
              to: "#graph-layout",
              detail: %{id: "highlights-drawer"}
            )
          }
          class="inline-flex items-center justify-center p-2 rounded-md bg-amber-500 text-white transition-all hover:bg-amber-600"
          data-panel-toggle="highlights-drawer"
          aria-label="Toggle highlights"
          title="Highlights"
        >
          <.icon name="hero-bookmark" class="w-4 h-4" />
        </button>

        <button
          type="button"
          phx-click={
            Phoenix.LiveView.JS.dispatch("toggle-panel",
              to: "#graph-layout",
              detail: %{id: "right-panel"}
            )
          }
          class="inline-flex items-center justify-center p-2 rounded-md bg-gray-600 text-white transition-all hover:bg-gray-700"
          data-panel-toggle="right-panel"
          aria-label="Toggle settings"
          title="Settings"
        >
          <.icon name="hero-adjustments-horizontal" class="w-4 h-4" />
        </button>
      </div>
    </div>
    """
  end
end
