defmodule DialecticWeb.Live.ModalComp do
  use DialecticWeb, :live_component

  alias DialecticWeb.ColUtils

  def update(assigns, socket) do
    node =
      case Map.get(assigns, :node) do
        %{} = n -> n
        _ -> %{}
      end

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
          
    <!-- Directional navigation buttons -->
          <!-- Top sticky bar (Parent) -->
          <div class="sticky top-0 z-10 flex justify-center bg-white/90 backdrop-blur px-2 py-1 md:py-2 border-b border-gray-100">
            <button
              phx-click={JS.push("node_move", value: %{direction: "up"})}
              disabled={!@nav_can_up}
              class={nav_button_class(@nav_can_up)}
              title="Go to parent"
            >
              <%= if @nav_parent_title do %>
                ↑
                <span
                  phx-hook="Markdown"
                  id={"markdown-parent-title-" <> @id}
                  data-md={@nav_parent_title}
                  data-title-only="true"
                >
                </span>
              <% else %>
                ↑ Parent
              <% end %>
            </button>
          </div>
          
    <!-- Side arrows (hidden on small screens) -->

          <article class="prose prose-stone prose-lg md:prose-xl lg:prose-2xl max-w-none selection-content space-y-4 min-h-[50vh]">
            <h2 class="text-xl sm:text-2xl md:text-3xl">
              <span
                phx-hook="Markdown"
                id={"markdown-title-" <> @id}
                data-md={Map.get(@node || %{}, :content, "")}
                data-title-only="true"
              >
              </span>
            </h2>

            <div class="text-base sm:text-lg">
              <div
                phx-hook="Markdown"
                id={"markdown-body-" <> @id}
                data-md={Map.get(@node || %{}, :content, "")}
                data-body-only="true"
              >
              </div>
            </div>
          </article>
          
    <!-- Bottom sticky bar (Child) -->
          <div class="sticky bottom-0 z-10 flex justify-center bg-white/90 backdrop-blur px-2 py-1 md:py-2 border-t border-gray-100">
            <button
              phx-click={JS.push("node_move", value: %{direction: "down"})}
              disabled={!@nav_can_down}
              class={nav_button_class(@nav_can_down)}
              title="Go to child"
            >
              <%= if @nav_child_title do %>
                <span
                  phx-hook="Markdown"
                  id={"markdown-child-title-" <> @id}
                  data-md={@nav_child_title}
                  data-title-only="true"
                >
                </span>
                ↓
              <% else %>
                Child ↓
              <% end %>
            </button>
          </div>
        </div>
      </.modal>
    </div>
    """
  end
end
