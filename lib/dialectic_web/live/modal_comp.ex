defmodule DialecticWeb.Live.ModalComp do
  use DialecticWeb, :live_component
  alias DialecticWeb.Live.TextUtils
  alias DialecticWeb.ColUtils

  def update(assigns, socket) do
    node = Map.get(assigns, :node, %{})
    parents = Map.get(node, :parents, []) || []
    children = Map.get(node, :children, []) || []

    default_up = is_list(parents) and parents != [] and List.first(parents) != nil
    default_down = is_list(children) and children != [] and List.first(children) != nil

    siblings_count =
      if is_list(parents) and parents != [] do
        parents
        |> Enum.flat_map(fn p -> Map.get(p, :children, []) || [] end)
        |> Enum.map(& &1.id)
        |> Enum.uniq()
        |> length()
      else
        0
      end

    default_left = siblings_count > 1
    default_right = siblings_count > 1

    assigns =
      assigns
      |> Map.put_new(:show, false)
      |> Map.put_new(:nav_can_up, default_up)
      |> Map.put_new(:nav_can_down, default_down)
      |> Map.put_new(:nav_can_left, default_left)
      |> Map.put_new(:nav_can_right, default_right)

    {:ok, assign(socket, assigns)}
  end

  def render(assigns) do
    ~H"""
    <div>
      <.modal
        on_cancel={JS.push("modal_closed")}
        class={ColUtils.message_border_class(@node.class) <> " modal-responsive"}
        id={"modal-" <> @id}
        show={@show}
      >
        <div
          class="modal-content relative pl-12 pr-12 pt-12 pb-12 sm:pl-14 sm:pr-14 sm:pt-14 sm:pb-14 md:pl-16 md:pr-16 md:pt-16 md:pb-16"
          id={"modal-" <> @id <> "-content"}
          phx-hook="TextSelectionHook"
          data-node-id={@node.id}
        >
          <!-- Directional navigation buttons -->
          <button
            phx-click={JS.push("node_move", value: %{direction: "up"})}
            disabled={!@nav_can_up}
            class={"absolute top-2 left-1/2 -translate-x-1/2 inline-flex items-center px-2.5 py-1.5 text-xs rounded-md border " <>
                    if @nav_can_up, do: "bg-white hover:bg-gray-50 border-gray-300", else: "bg-gray-100 text-gray-400 border-gray-200 cursor-not-allowed pointer-events-none"}
            title="Go to parent"
          >
            ↑
          </button>
          <button
            phx-click={JS.push("node_move", value: %{direction: "down"})}
            disabled={!@nav_can_down}
            class={"absolute bottom-2 left-1/2 -translate-x-1/2 inline-flex items-center px-2.5 py-1.5 text-xs rounded-md border " <>
                    if @nav_can_down, do: "bg-white hover:bg-gray-50 border-gray-300", else: "bg-gray-100 text-gray-400 border-gray-200 cursor-not-allowed pointer-events-none"}
            title="Go to child"
          >
            ↓
          </button>
          <button
            phx-click={JS.push("node_move", value: %{direction: "left"})}
            disabled={!@nav_can_left}
            class={"absolute left-2 top-1/2 -translate-y-1/2 inline-flex items-center px-2.5 py-1.5 text-xs rounded-md border " <>
                    if @nav_can_left, do: "bg-white hover:bg-gray-50 border-gray-300", else: "bg-gray-100 text-gray-400 border-gray-200 cursor-not-allowed pointer-events-none"}
            title="Go to previous sibling"
          >
            ←
          </button>
          <button
            phx-click={JS.push("node_move", value: %{direction: "right"})}
            disabled={!@nav_can_right}
            class={"absolute right-2 top-1/2 -translate-y-1/2 inline-flex items-center px-2.5 py-1.5 text-xs rounded-md border " <>
                    if @nav_can_right, do: "bg-white hover:bg-gray-50 border-gray-300", else: "bg-gray-100 text-gray-400 border-gray-200 cursor-not-allowed pointer-events-none"}
            title="Go to next sibling"
          >
            →
          </button>
          <article class="prose prose-stone prose-lg md:prose-xl lg:prose-2xl max-w-none selection-content space-y-4">
            <h2 class="text-xl sm:text-2xl md:text-3xl">
              {TextUtils.modal_title(@node.content, @node.class || "")}
            </h2>

            <div class="text-base sm:text-lg">
              {TextUtils.full_html(@node.content || "")}
            </div>
          </article>
        </div>
      </.modal>
    </div>
    """
  end
end
