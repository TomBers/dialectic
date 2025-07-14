defmodule DialecticWeb.NoteMenuComp do
  use DialecticWeb, :live_component

  def update(assigns, socket) do
    {:ok, socket |> assign(assigns)}
  end

  def render(assigns) do
    ~H"""
    <div class="rounded-md px-4 py-3 shadow-sm inline-flex space-x-4 text-xs">
      <div class="flex items-center space-x-3 border border-gray-200 rounded-md px-3 py-2 bg-gray-50">
        <div class="text-xs font-semibold text-gray-500 mr-2">Actions:</div>
        <!-- Improved version with clearer purpose -->
        <!-- Redesigned with clearer visual states -->
        <%= if Enum.any?(@node.noted_by, fn u -> u == @user end) do %>
          <button
            phx-click="unnote"
            phx-value-node={@node.id}
            tabindex="-1"
            class="bg-indigo-50 text-indigo-700 hover:bg-indigo-100 px-3 py-1.5 rounded-md text-xs font-semibold transition-colors flex items-center border border-indigo-200 shadow-sm"
            title="Remove from your notes"
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="h-3 w-3 mr-1"
              viewBox="0 0 24 24"
              fill="currentColor"
            >
              <path
                fill-rule="evenodd"
                d="M10.788 3.21c.448-1.077 1.976-1.077 2.424 0l2.082 5.007 5.404.433c1.164.093 1.636 1.545.749 2.305l-4.117 3.527 1.257 5.273c.271 1.136-.964 2.033-1.96 1.425L12 18.354 7.373 21.18c-.996.608-2.231-.29-1.96-1.425l1.257-5.273-4.117-3.527c-.887-.76-.415-2.212.749-2.305l5.404-.433 2.082-5.006z"
                clip-rule="evenodd"
              />
            </svg>
            Noted ({length(@node.noted_by)})
          </button>
        <% else %>
          <button
            phx-click="note"
            phx-value-node={@node.id}
            tabindex="-1"
            class="bg-gray-50 text-gray-600 hover:bg-gray-100 px-3 py-1.5 rounded-md text-xs font-semibold transition-colors flex items-center border border-gray-200 shadow-sm"
            title="Add to your notes"
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="h-3 w-3 mr-1"
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
            Note
            <%= if length(@node.noted_by) > 0 do %>
              ({length(@node.noted_by)})
            <% end %>
          </button>
        <% end %>

        <.link
          navigate={~p"/#{@graph_id}/story/#{@node.id}"}
          tabindex="-1"
          class="bg-amber-50 text-amber-700 hover:bg-amber-100 px-3 py-1.5 rounded-md text-xs font-semibold transition-colors flex items-center border border-amber-200 shadow-sm"
          title="View conversation thread from root to this node"
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            class="h-3 w-3 mr-1"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M7 8h10M7 12h4m1 8l-4-4H5a2 2 0 01-2-2V6a2 2 0 012-2h14a2 2 0 012 2v8a2 2 0 01-2 2h-3l-4 4z"
            />
          </svg>
          Thread
        </.link>
        <.link
          navigate={~p"/#{@graph_id}/focus/#{@node.id}"}
          tabindex="-1"
          class="bg-emerald-50 text-emerald-700 hover:bg-emerald-100 px-3 py-1.5 rounded-md text-xs font-semibold transition-colors flex items-center border border-emerald-200 shadow-sm"
          title="Chat interface for rapid idea expansion"
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            class="h-3 w-3 mr-1"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z"
            />
          </svg>
          Chat
        </.link>
      </div>

      <div class="flex items-center space-x-2 border border-gray-200 rounded-md px-2 py-2 bg-gray-50">
        <div class="text-xs font-semibold text-gray-500 mr-1">Export:</div>
        <.link
          navigate={~p"/#{@graph_id}/linear"}
          target="_blank"
          rel="noopener noreferrer"
          id="link-to-pdf-print"
          class="inline-flex items-center text-xs font-semibold px-3 py-1.5 rounded-md bg-red-50 border border-red-200 text-red-700 hover:bg-red-100 hover:text-red-800 transition-colors shadow-sm"
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            class="h-4 w-4 mr-1.5"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
            stroke-width="2"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
            />
          </svg>
          PDF
        </.link>

        <.link
          href={"/api/graphs/json/#{@graph_id}"}
          download={"#{@graph_id}.json"}
          class="inline-flex items-center text-xs font-semibold px-3 py-1.5 rounded-md bg-blue-50 border border-blue-200 text-blue-700 hover:bg-blue-100 hover:text-blue-800 transition-colors shadow-sm"
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            class="h-4 w-4 mr-1.5"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
            stroke-width="2"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              d="M7 7h10M7 11h10m-5 4h5m-9 2H9m13 0h-9m-1 4l-3-3H5a2 2 0 01-2-2V6a2 2 0 012-2h14a2 2 0 012 2v8a2 2 0 01-2 2h-3l-4 4z"
            />
          </svg>
          JSON
        </.link>

        <.link
          href={"/api/graphs/md/#{@graph_id}"}
          download={"#{@graph_id}.md"}
          class="inline-flex items-center text-xs font-semibold px-3 py-1.5 rounded-md bg-purple-50 border border-purple-200 text-purple-700 hover:bg-purple-100 hover:text-purple-800 transition-colors shadow-sm"
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            class="h-4 w-4 mr-1.5"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
            stroke-width="2"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              d="M7 8h10M7 12h4m1 8l-4-4H5a2 2 0 01-2-2V6a2 2 0 012-2h14a2 2 0 012 2v8a2 2 0 01-2 2h-3l-4 4z"
            />
          </svg>
          Markdown
        </.link>
      </div>
    </div>
    """
  end
end
