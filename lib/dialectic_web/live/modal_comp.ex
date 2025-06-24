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
        class={ColUtils.message_border_class(@node.class)}
        id={"modal-" <> @node.id}
      >
        <div
          class="modal-content relative"
          id={"modal-content-" <> @node.id}
          phx-hook="TextSelectionHook"
          data-node-id={@node.id}
        >
          <article class="prose prose-stone prose-2xl max-w-none selection-content space-y-4">
            <h2>
              {TextUtils.modal_title(@node.content, @node.class || "")}
            </h2>
            <div>
              {TextUtils.full_html(@node.content || "")}
            </div>
          </article>
          
    <!-- Modal selection action button (hidden by default) -->
          <div class="selection-actions hidden absolute bg-white shadow-md rounded-md p-1 z-10">
            <button class="bg-blue-500 hover:bg-blue-600 text-white text-xs py-1 px-2 rounded">
              Ask about selection
            </button>
          </div>
        </div>
      </.modal>
    </div>
    """
  end
end
