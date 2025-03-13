defmodule DialecticWeb.MermaidComp do
  use DialecticWeb, :live_component

  def render(assigns) do
    ~H"""
    <div class="mermaid-container">
      <div class="mermaid-controls">
        <div class="control-group">
          <label>Zoom:</label>
          <button phx-click="zoom_in" phx-target={@myself} class="zoom-btn">+</button>
          <button phx-click="zoom_out" phx-target={@myself} class="zoom-btn">-</button>
          <button phx-click="zoom_reset" phx-target={@myself} class="zoom-btn">Reset</button>
        </div>
      </div>

      <div class="mermaid-diagram-wrapper" style={"zoom: #{@zoom}%;"}>
        <div
          id={"#{@id}-diagram"}
          class="mermaid-diagram"
          phx-hook="MermaidInit"
          phx-update="ignore"
          data-mermaid={@mermaid_content}
        >
          {@mermaid_content}
        </div>
      </div>

      <%= if @selected_node do %>
        <div class="selected-node">
          <h3>Selected Node: {@selected_node.id}</h3>
          <div class="node-details">
            <p><strong>Type:</strong> {@selected_node.class || "Default"}</p>
            <%= if @selected_node.user do %>
              <p><strong>User:</strong> {@selected_node.user}</p>
            <% end %>
            <div class="node-content">
              {@selected_node.content}
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  def mount(socket) do
    {:ok, socket}
  end

  def update(assigns, socket) do
    socket =
      socket
      |> assign(id: assigns.id)
      |> assign(graph: assigns.graph)
      |> assign(direction: assigns[:direction] || "TD")
      |> assign(zoom: assigns[:zoom] || 100)
      |> assign(selected_node: assigns[:selected_node])
      |> update_mermaid_content()

    {:ok, socket}
  end

  def handle_event("zoom_in", _, socket) do
    socket =
      socket
      |> assign(zoom: min(socket.assigns.zoom + 10, 200))

    {:noreply, socket}
  end

  def handle_event("zoom_out", _, socket) do
    socket =
      socket
      |> assign(zoom: max(socket.assigns.zoom - 10, 50))

    {:noreply, socket}
  end

  def handle_event("zoom_reset", _, socket) do
    socket =
      socket
      |> assign(zoom: 100)

    {:noreply, socket}
  end

  def handle_event("node_selected", %{"id" => node_id}, socket) do
    # Find the selected node in the graph data
    selected_node =
      socket.assigns.graph["nodes"]
      |> Enum.find(fn node -> node["id"] == node_id end)

    socket = assign(socket, selected_node: selected_node)

    # Send the selection to the parent LiveView if needed
    send(self(), {:node_selected, selected_node})

    {:noreply, socket}
  end

  defp update_mermaid_content(socket) do
    # Generate Mermaid syntax from the graph data
    # mermaid_content =
    #   Dialectic.Converters.Mermaid.json_to_mermaid(
    #     socket.assigns.graph,
    #     direction: socket.assigns.direction
    #   )

    assign(socket, mermaid_content: socket.assigns.graph)
  end
end
