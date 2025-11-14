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

  defp nav_button_class(enabled) do
    base = "inline-flex items-center px-3 py-1.5 text-sm rounded-md border "

    if enabled do
      base <> "bg-white hover:bg-gray-50 border-gray-300"
    else
      base <> "bg-gray-100 text-gray-400 border-gray-200 cursor-not-allowed pointer-events-none"
    end
  end

  def render(assigns) do
    ~H"""
    <div>
      <.modal
        on_cancel={JS.push("modal_closed")}
        class={ColUtils.message_border_class(Map.get(@node || %{}, :class, "default")) <> " modal-responsive"}
        id={"modal-" <> @id}
        show={@show}
      >
        <div
          class="modal-content relative px-4 sm:px-14 md:px-16"
          id={"modal-" <> @id <> "-inner"}
          phx-hook="TextSelectionHook"
          data-node-id={Map.get(@node || %{}, :id, "")}
        >
          <span phx-window-keydown="node_move" phx-key="ArrowUp" phx-value-direction="up"></span>
          <span phx-window-keydown="node_move" phx-key="ArrowDown" phx-value-direction="down"></span>
          <span phx-window-keydown="node_move" phx-key="ArrowLeft" phx-value-direction="left"></span>
          <span phx-window-keydown="node_move" phx-key="ArrowRight" phx-value-direction="right">
          </span>
          <!-- Directional navigation buttons -->
          <!-- Top sticky bar (Parent) -->
          <div class="sticky top-0 z-10 flex justify-center bg-white/90 backdrop-blur px-2 py-1 md:py-2 border-b border-gray-100">
            <button
              phx-click={JS.push("node_move", value: %{direction: "up"})}
              disabled={!@nav_can_up}
              class={nav_button_class(@nav_can_up)}
              title="Go to parent"
            >
              {if @nav_parent_title, do: "↑ " <> @nav_parent_title, else: "↑ Parent"}
            </button>
          </div>
          
    <!-- Side arrows (hidden on small screens) -->

          <article class="prose prose-stone prose-lg md:prose-xl lg:prose-2xl max-w-none selection-content space-y-4 min-h-[50vh]">
            <h2 class="text-xl sm:text-2xl md:text-3xl">
              <span
                phx-hook="Markdown"
                id={"markdown-title-" <> @id}
                data-md={@node.content || ""}
                data-title-only="true"
              >
              </span>
            </h2>

            <div class="text-base sm:text-lg">
              <div
                phx-hook="Markdown"
                id={"markdown-body-" <> @id}
                data-md={@node.content || ""}
                data-body-only="true"
              >
              </div>
            </div>
          </article>
          <!-- Modal selection action button (hidden by default) -->
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
          <!-- Bottom sticky bar (Child) -->
          <div class="sticky bottom-0 z-10 flex justify-center bg-white/90 backdrop-blur px-2 py-1 md:py-2 border-t border-gray-100">
            <button
              phx-click={JS.push("node_move", value: %{direction: "down"})}
              disabled={!@nav_can_down}
              class={nav_button_class(@nav_can_down)}
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
