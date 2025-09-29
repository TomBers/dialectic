defmodule DialecticWeb.ChatMsgComp do
  use DialecticWeb, :live_component
  alias DialecticWeb.Live.TextUtils

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      # Default cutoff length
      |> assign_new(:cut_off, fn -> 500 end)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div
      class={[
        "node mb-4 rounded-lg shadow-sm",
        "flex items-start gap-3 bg-white border-l-4",
        DialecticWeb.ColUtils.message_border_class(@node.class)
      ]}
      id={"node-" <> @node.id}
    >
      <div class="shrink-0">
        <h2 class={keyboard_shortcut(@node.class)}>
          <span class="transform">{@node.id}</span>
        </h2>
      </div>

      <.live_component
        module={DialecticWeb.Live.ModalComp}
        node={@node}
        id={"chat-msg-modal-comp-" <> @node.id}
      />

      <div class="proposition flex-1 max-w-none relative">
        <div
          class="summary-content relative"
          id={"summary-content-" <> @node.id}
          phx-hook="TextSelectionHook"
          data-node-id={@node.id}
        >
          <article class="prose prose-stone prose-xl selection-content">
            {TextUtils.truncated_html(@node.content || "", @cut_off)}
          </article>
          
    <!-- Summary selection action button (hidden by default) -->
          <div class="selection-actions hidden absolute bg-white shadow-lg rounded-lg p-2 z-10 border border-gray-200">
            <button class="bg-blue-500 hover:bg-blue-600 text-white text-xs py-1.5 px-3 rounded-full flex items-center">
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
                  d="M8.228 9c.549-1.165 2.03-2 3.772-2 2.21 0 4 1.343 4 3 0 1.4-1.278 2.575-3.006 2.907-.542.104-.994.54-.994 1.093m0 3h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                />
              </svg>
              Ask about selection
            </button>
          </div>
        </div>

        <%= if String.length(@node.content || "") > @cut_off do %>
          <div class="flex justify-end">
            <button
              phx-click={show_modal("modal-chat-msg-modal-comp-#{@node.id}")}
              class="mt-2 text-blue-600 hover:text-blue-800 p-1.5 rounded-full transition-colors duration-200 focus:outline-none focus:ring-2 focus:ring-blue-300"
              aria-label="Open in modal"
            >
              <svg
                xmlns="http://www.w3.org/2000/svg"
                width="16"
                height="16"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
                class="feather feather-maximize-2"
              >
                <polyline points="15 3 21 3 21 9"></polyline>
                <polyline points="9 21 3 21 3 15"></polyline>
                <line x1="21" y1="3" x2="14" y2="10"></line>
                <line x1="3" y1="21" x2="10" y2="14"></line>
              </svg>
            </button>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp keyboard_shortcut(class) do
    cols =
      case class do
        # "user" -> "border-red-400"
        "answer" -> "border-blue-400 text-blue-700"
        "thesis" -> "border-green-400 text-green-700"
        "antithesis" -> "border-red-400 text-red-700"
        "synthesis" -> "border-purple-600 text-purple-700"
        "question" -> "border-amber-400 text-amber-700"
        _ -> "border border-gray-200 bg-white"
      end

    "w-8 h-8 flex items-center p-4 justify-center rounded-lg font-mono text-sm border-2 transform " <>
      cols
  end
end
