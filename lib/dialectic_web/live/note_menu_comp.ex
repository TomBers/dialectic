defmodule DialecticWeb.NoteMenuComp do
  use DialecticWeb, :live_component

  def update(assigns, socket) do
    {:ok, socket |> assign(assigns)}
  end

  def render(assigns) do
    ~H"""
    <div class="rounded-md px-3 py-2 shadow-sm inline-flex space-x-3 text-xs">
      <div class="flex items-center space-x-2">
        <!-- Improved version with clearer purpose -->
        <!-- Redesigned with clearer visual states -->
        <%= if Enum.any?(@node.noted_by, fn u -> u == @user end) do %>
          <button
            phx-click="unnote"
            phx-value-node={@node.id}
            tabindex="-1"
            class="bg-indigo-50 text-indigo-700 hover:bg-indigo-100 px-2 py-0.5 rounded-full text-xs font-medium transition-colors flex items-center"
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
            class="bg-gray-50 text-gray-600 hover:bg-gray-100 px-2 py-0.5 rounded-full text-xs font-medium transition-colors flex items-center"
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
          class="bg-amber-50 text-amber-700 hover:bg-amber-100 px-2 py-0.5 rounded-full text-xs font-medium transition-colors flex items-center"
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
          class="bg-emerald-50 text-emerald-700 hover:bg-emerald-100 px-2 py-0.5 rounded-full text-xs font-medium transition-colors flex items-center"
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
    </div>
    """
  end
end
