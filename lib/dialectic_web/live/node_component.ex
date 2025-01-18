defmodule DialecticWeb.NodeComponent do
  use DialecticWeb, :live_component
  alias Dialectic.Graph.Vertex

  def get_parent(graph, vertex) do
    Vertex.find_parent(graph, vertex) |> Map.get(:id, "")
  end

  def get_children(graph, vertex) do
    Vertex.find_children(graph, vertex) |> Enum.map(& &1.id)
  end

  def render(assigns) do
    ~H"""
    <div class="node">
      <p><strong>ID:</strong> {@node.id}</p>
      <% parent = get_parent(assigns.graph, assigns.node) %>
      <p>
        Parent:
        <%= if parent do %>
          <a href="#" phx-click="node_clicked" phx-value-id={parent}>{parent}</a>
        <% else %>
          None
        <% end %>
      </p>
      <p>
        Children:
        <%= for child <- get_children(assigns.graph, assigns.node) do %>
          <a href="#" phx-click="node_clicked" phx-value-id={child}>{child}</a>
        <% end %>
      </p>
      <.form for={@form} phx-submit="save">
        <div>
          <.input field={@form[:description]} type="textarea" label="Name" />
        </div>

        <div>
          <.button type="submit">Save</.button>
        </div>
      </.form>
      <br />
      <btn
        phx-click="generate_thesis"
        class="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded"
      >
        Generate Theis
      </btn>
    </div>
    """
  end
end
