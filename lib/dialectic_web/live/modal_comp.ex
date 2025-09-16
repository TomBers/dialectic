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
      |> Map.put_new(:nav_parent_title, nil)
      |> Map.put_new(:nav_child_title, nil)

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
          class="modal-content relative px-4 sm:px-14 md:px-16"
          id={"modal-" <> @id <> "-inner"}
          phx-hook="TextSelectionHook"
          data-node-id={@node.id}
        >
          <span phx-window-keydown="node_move" phx-key="ArrowUp" phx-value-direction="up"></span>
          <span phx-window-keydown="node_move" phx-key="ArrowDown" phx-value-direction="down"></span>
          <!-- Directional navigation buttons -->
          <!-- Top sticky bar (Parent) -->
          <div class="sticky top-0 z-10 flex justify-center bg-white/90 backdrop-blur px-2 py-1 md:py-2 border-b border-gray-100">
            <button
              phx-click={JS.push("node_move", value: %{direction: "up"})}
              disabled={!@nav_can_up}
              class={"inline-flex items-center px-3 py-1.5 text-sm rounded-md border " <>
                      if @nav_can_up, do: "bg-white hover:bg-gray-50 border-gray-300", else: "bg-gray-100 text-gray-400 border-gray-200 cursor-not-allowed pointer-events-none"}
              title="Go to parent"
            >
              {if @nav_parent_title, do: "↑ " <> @nav_parent_title, else: "↑ Parent"}
            </button>
          </div>
          
    <!-- Side arrows (hidden on small screens) -->

          <article class="prose prose-stone prose-lg md:prose-xl lg:prose-2xl max-w-none selection-content space-y-4">
            <h2 class="text-xl sm:text-2xl md:text-3xl">
              {TextUtils.modal_title(@node.content, @node.class || "")}
            </h2>

            <div class="text-base sm:text-lg">
              {TextUtils.full_html(@node.content || "")}
            </div>
          </article>
          <!-- Bottom sticky bar (Child) -->
          <div class="sticky bottom-0 z-10 flex justify-center bg-white/90 backdrop-blur px-2 py-1 md:py-2 border-t border-gray-100">
            <button
              phx-click={JS.push("node_move", value: %{direction: "down"})}
              disabled={!@nav_can_down}
              class={"inline-flex items-center px-3 py-1.5 text-sm rounded-md border " <>
                            if @nav_can_down, do: "bg-white hover:bg-gray-50 border-gray-300", else: "bg-gray-100 text-gray-400 border-gray-200 cursor-not-allowed pointer-events-none"}
              title="Go to child"
            >
              {if @nav_child_title, do: @nav_child_title <> " ↓", else: "Child ↓"}
            </button>
          </div>
        </div>
      </.modal>
    </div>
    """
  end
end
