defmodule DialecticWeb.NodeMenuComp do
  use Phoenix.LiveComponent

  def render(assigns) do
    ~H"""
    <div id="node-menu" class="graph-tooltip" style={get_styles(@visible, @position)}>
      <div class="menu-buttons">
        <button class="menu-button" phx-click="node_reply" phx-value-id={@node_id}>
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

        <button class="menu-button" phx-click="node_branch" phx-value-id={@node_id}>
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

        <button class="menu-button" phx-click="node_combine" phx-value-id={@node_id}>
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
          <span class="label">Combine and Summarise</span>
        </button>

        <button class="menu-button show_more_modal" phx-click="node_showfull" phx-value-id={@node_id}>
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
              <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"></path>
              <polyline points="14 2 14 8 20 8"></polyline>
              <line x1="16" y1="13" x2="8" y2="13"></line>
              <line x1="16" y1="17" x2="8" y2="17"></line>
              <polyline points="10 9 9 9 8 9"></polyline>
            </svg>
          </span>
          <span class="label">Full Text</span>
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
    """

    visibility = if visible, do: "display: block;", else: "display: none;"

    position_style =
      case position do
        %{x: x, y: y} when is_number(x) and is_number(y) ->
          # Center the menu horizontally on the node
          # x represents the center of the node
          x_val =
            if is_map_key(position, "width") or is_map_key(position, :width) do
              width = position["width"] || position[:width] || 0
              "left: #{x - width / 2}px;"
            else
              # Assume 80px menu width if not provided
              "left: #{x - 40}px;"
            end

          "#{x_val} top: #{y}px;"

        _ ->
          ""
      end

    base_styles <> visibility <> position_style
  end

  def update(assigns, socket) do
    {:ok,
     assign(socket,
       visible: Map.get(assigns, :visible, false),
       position: Map.get(assigns, :position, %{x: 0, y: 0}),
       node_id: Map.get(assigns, :node_id, nil)
     )}
  end
end
