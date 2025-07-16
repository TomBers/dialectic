defmodule DialecticWeb.Live.ModalComp do
  use DialecticWeb, :live_component
  alias DialecticWeb.Live.TextUtils
  alias DialecticWeb.ColUtils

  def update(assigns, socket) do
    {:ok, socket |> assign(assigns)}
  end

  def render(assigns) do
    ~H"""
    <div>
      <.modal
        on_cancel={JS.push("modal_closed")}
        class={ColUtils.message_border_class(@node.class) <> " modal-responsive"}
        id={"modal-" <> @node.id}
      >
        <div
          class="modal-content relative px-2 sm:px-4 md:px-6"
          id={"modal-content-" <> @node.id}
          phx-hook="TextSelectionHook"
          data-node-id={@node.id}
        >
          <article class="prose prose-stone prose-lg md:prose-xl lg:prose-2xl max-w-none selection-content space-y-4">
            <h2 class="text-xl sm:text-2xl md:text-3xl">
              {TextUtils.modal_title(@node.content, @node.class || "")}
            </h2>
            <div class="text-base sm:text-lg">
              {TextUtils.full_html(@node.content || "")}
            </div>
          </article>
          
    <!-- Modal selection action button (hidden by default) -->
          <div class="selection-actions hidden absolute bg-white shadow-lg rounded-lg p-1 sm:p-2 z-10 border border-gray-200">
            <button class="bg-blue-500 hover:bg-blue-600 text-white text-xs py-1 sm:py-1.5 px-2 sm:px-3 rounded-full flex items-center">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="h-3 w-3 mr-0.5 sm:mr-1"
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
      </.modal>
    </div>
    """
  end
end
