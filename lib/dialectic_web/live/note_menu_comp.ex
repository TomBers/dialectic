defmodule DialecticWeb.NoteMenuComp do
  use DialecticWeb, :live_component

  def update(assigns, socket) do
    {:ok, socket |> assign(assigns)}
  end

  defp keyboard_shortcut(class) do
    cols =
      case class do
        # "user" -> "border-red-400"
        "answer" -> "border-blue-400 text-blue-700"
        "thesis" -> "border-green-400 text-green-700"
        "antithesis" -> "border-red-400 text-red-700"
        "synthesis" -> "border-purple-600 text-purple-700"
        _ -> "border border-gray-200 bg-white"
      end

    "w-8 h-8 flex items-center p-4 justify-center rounded-lg font-mono text-sm border-2 " <>
      cols
  end

  def render(assigns) do
    ~H"""
    <div class="rounded-md px-3 py-2 shadow-sm inline-flex space-x-3 text-xs">
      <span class="flex items-center">
        <%= if @node.class == "user" do %>
          <span class="text-gray-500">By:</span>
          <span class="font-semibold ml-1 text-gray-700">{@node.user}</span>
        <% end %>
      </span>
      <div class="shrink-0">
        <h2 class={keyboard_shortcut(@node.class)}>
          <span class="transform">{@node.id}</span>
        </h2>
      </div>

      <div class="flex items-center bg-amber-50 px-2 py-0.5 rounded-full" title="Number of stars">
        <span class="text-amber-600 mr-1">{length(@node.noted_by)}</span>
        <svg
          xmlns="http://www.w3.org/2000/svg"
          class="h-3.5 w-3.5 text-amber-500"
          fill="currentColor"
          viewBox="0 0 24 24"
        >
          <path d="M12 17.27L18.18 21l-1.64-7.03L22 9.24l-7.19-.61L12 2 9.19 8.63 2 9.24l5.46 4.73L5.82 21z" />
        </svg>
      </div>

      <div class="flex items-center space-x-2">
        <%= if Enum.any?(@node.noted_by, fn u -> u == @user end) do %>
          <button
            phx-click="unnote"
            phx-value-node={@node.id}
            tabindex="-1"
            class="bg-red-50 text-red-700 hover:bg-red-100 px-2 py-0.5 rounded-full text-xs font-medium transition-colors flex items-center"
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
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M6 18L18 6M6 6l12 12"
              />
            </svg>
            Unnote
          </button>
        <% else %>
          <button
            phx-click="note"
            phx-value-node={@node.id}
            tabindex="-1"
            class="bg-green-50 text-green-700 hover:bg-green-100 px-2 py-0.5 rounded-full text-xs font-medium transition-colors flex items-center"
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
          </button>
        <% end %>

        <.link
          navigate={"?node=" <> @node.id}
          tabindex="-1"
          class="bg-blue-50 text-blue-700 hover:bg-blue-100 px-2 py-0.5 rounded-full text-xs font-medium transition-colors flex items-center"
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
              d="M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1"
            />
          </svg>
          Link
        </.link>

        <%= if @user && @node.user == @user && length(@node.children) == 0  do %>
          <div class="flex items-center space-x-1">
            <button
              phx-click="delete"
              phx-confirm="Are you sure you want to delete this note?"
              phx-value-node={@node.id}
              tabindex="-1"
              class="bg-red-50 text-red-700 hover:bg-red-100 px-2 py-0.5 rounded-full text-xs font-medium transition-colors flex items-center"
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
                  d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"
                />
              </svg>
              Delete
            </button>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
