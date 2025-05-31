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
          Conversation
        </.link>
        <.link
          navigate={~p"/#{@graph_id}/focus/#{@node.id}"}
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
          Focus
        </.link>
      </div>
    </div>
    """
  end
end
