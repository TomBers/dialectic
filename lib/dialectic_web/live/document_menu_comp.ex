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
        <% noted? = Enum.any?(Map.get(@node || %{}, :noted_by, []), fn u -> u == @user end) %>

        <button
          type="button"
          class={[
            "inline-flex items-center justify-center gap-1.5 px-3 py-1.5 rounded-md transition-all disabled:opacity-50 disabled:cursor-not-allowed text-sm font-medium",
            if(noted?,
              do: "bg-yellow-400 text-gray-900 hover:bg-yellow-500",
              else: "bg-gray-100 text-gray-700 hover:bg-yellow-400 hover:text-gray-900"
            )
          ]}
          phx-click={if noted?, do: "unnote", else: "note"}
          phx-value-node={@node && @node.id}
          disabled={is_nil(@graph_id)}
          title={if noted?, do: "Remove from your notes", else: "Add to your notes"}
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
          <span>{if noted?, do: "Starred", else: "Star"}</span>
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
            class="inline-flex items-center justify-center gap-1.5 px-3 py-1.5 rounded-md bg-gray-700 text-white transition-all hover:bg-gray-800 text-sm font-medium"
            title="Open linear view"
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
            <span>Read</span>
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
