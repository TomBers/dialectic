defmodule DialecticWeb.NodeMenuComp do
  use DialecticWeb, :live_component

  def render(assigns) do
    ~H"""
    <div
      id={"node-menu-" <> @node_id}
      class="graph-tooltip overflow-auto"
      style={get_styles(@visible, @position)}
      data-position={Jason.encode!(@position)}
      phx-hook="NodeMenuHook"
    >
      <div
        class={[
          "p-2 rounded-lg shadow-sm",
          "flex items-start gap-3 bg-white border-4",
          message_border_class(@node.class)
        ]}
        id={"tt-node-" <> @node.id}
      >
        <div
          class="summary-content"
          id={"tt-summary-content-" <> @node.id}
          phx-hook="TextSelectionHook"
          data-node-id={@node.id}
        >
          <article class="prose prose-stone prose-sm selection-content">
            {truncated_html(@node.content || "", @cut_off)}
          </article>
          <div class="selection-actions hidden absolute bg-white shadow-md rounded-md p-1 z-10">
            <button class="bg-blue-500 hover:bg-blue-600 text-white text-xs py-1 px-2 rounded">
              Ask about selection
            </button>
          </div>
          <%= if String.length(@node.content || "") > @cut_off do %>
            <div class="flex justify-end">
              <button
                phx-click={show_modal("modal-" <> @node.id)}
                class="show_more_modal mt-2 text-blue-600 hover:text-blue-800 text-sm font-medium focus:outline-none"
              >
                Show more
              </button>
            </div>
          <% end %>
        </div>
      </div>
      <.form for={@form} phx-submit="answer" id={"tt-form-" <> @node.id}>
        <div class="flex-1 mb-4">
          <.input
            :if={@node_id != "NewNode"}
            field={@form[:content]}
            tabindex="0"
            type="text"
            id={"tt-input-" <> @node.id}
            placeholder="Add comment"
          />
        </div>
      </.form>

      <div class="menu-buttons">
        <button
          class="menu-button"
          phx-click="node_reply"
          phx-value-id={@node_id}
          id={"reply-button-" <> @node_id}
        >
          <span class="icon">
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
            >
              <path d="M21 11.5a8.38 8.38 0 0 1-.9 3.8 8.5 8.5 0 0 1-7.6 4.7 8.38 8.38 0 0 1-3.8-.9L3 21l1.9-5.7a8.38 8.38 0 0 1-.9-3.8 8.5 8.5 0 0 1 4.7-7.6 8.38 8.38 0 0 1 3.8-.9h.5a8.48 8.48 0 0 1 8 8v.5z">
              </path>
            </svg>
          </span>
          <span class="label">Ask Question</span>
        </button>

        <button
          class="menu-button"
          phx-click="node_branch"
          phx-value-id={@node_id}
          id={"branch-button-" <> @node_id}
        >
          <span class="icon">
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
            >
              <line x1="6" y1="3" x2="6" y2="15"></line>
              <circle cx="18" cy="6" r="3"></circle>
              <circle cx="6" cy="18" r="3"></circle>
              <path d="M18 9a9 9 0 0 1-9 9"></path>
            </svg>
          </span>
          <span class="label">Pros and Cons</span>
        </button>

        <button
          class="menu-button"
          phx-click="node_combine"
          phx-value-id={@node_id}
          id={"combine-button-" <> @node_id}
        >
          <span class="icon">
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
            >
              <rect x="8" y="2" width="8" height="4" rx="1" ry="1"></rect>
              <path d="M16 4h2a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h2">
              </path>
              <path d="M12 11h4"></path>
              <path d="M12 16h4"></path>
              <path d="M8 11h.01"></path>
              <path d="M8 16h.01"></path>
            </svg>
          </span>
          <span class="label">Combine</span>
        </button>
      </div>
    </div>
    """
  end

  defp get_styles(visible, position) do
    base_styles = """
    position: fixed;
    z-index: 10;
    background-color: white;
    border-radius: 4px;
    box-shadow: 0 2px 10px rgba(0, 0, 0, 0.2);
    padding: 5px;
    transition: opacity 0.2s;
    max-width: 400px;
    max-height: 80vh;
    """

    visibility = if visible, do: "display: block;", else: "display: none;"

    position_style =
      case position do
        %{x: x, y: y} when is_number(x) and is_number(y) ->
          # Get estimated dimensions
          estimated_width = position[:estimated_width] || position["estimated_width"] || 300
          estimated_height = position[:estimated_height] || position["estimated_height"] || 300

          # Get viewport dimensions from JS or use sensible defaults
          viewport_width = position[:viewport_width] || position["viewport_width"] || 1920
          viewport_height = position[:viewport_height] || position["viewport_height"] || 1080

          # Calculate initial position (centered on node)
          node_width = position[:width] || position["width"] || 0
          initial_x = x - node_width / 2
          initial_y = y

          # Adjust if the tooltip would go off-screen
          adjusted_x =
            cond do
              initial_x + estimated_width > viewport_width ->
                viewport_width - estimated_width - 20

              initial_x < 20 ->
                20

              true ->
                initial_x
            end

          adjusted_y =
            cond do
              initial_y + estimated_height > viewport_height ->
                viewport_height - estimated_height - 20

              initial_y < 20 ->
                20

              true ->
                initial_y
            end

          "left: #{adjusted_x}px; top: #{adjusted_y}px;"

        _ ->
          "left: 50%; top: 50%; transform: translate(-50%, -50%);"
      end

    base_styles <> visibility <> position_style
  end

  def update(assigns, socket) do
    node = Map.get(assigns, :node, %{})
    node_id = Map.get(node, :id)

    {:ok,
     assign(socket,
       visible: Map.get(assigns, :visible, false),
       position: Map.get(assigns, :position, %{x: 0, y: 0}),
       node_id: node_id,
       node: node,
       user: Map.get(assigns, :user, nil),
       form: Map.get(assigns, :form, nil),
       cut_off: Map.get(assigns, :cut_off, 500)
     )}
  end

  defp message_border_class(class) do
    case class do
      # "user" -> "border-red-400"
      "answer" -> "border-blue-400"
      "thesis" -> "border-green-400"
      "antithesis" -> "border-red-400"
      "synthesis" -> "border-purple-600"
      _ -> "border border-gray-200 bg-white"
    end
  end

  defp truncated_html(content, cut_off) do
    # If content is already under the cutoff, just return the full text
    if String.length(content) <= cut_off do
      full_html(content)
    else
      truncated = String.slice(content, 0, cut_off) <> "..."
      Earmark.as_html!(truncated) |> Phoenix.HTML.raw()
    end
  end

  defp full_html(content) do
    Earmark.as_html!(content) |> Phoenix.HTML.raw()
  end
end
