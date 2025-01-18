defmodule DialecticWeb.NodeComponent do
  use DialecticWeb, :live_component

  def render(assigns) do
    ~H"""
    <div class="node">
      <p><strong>ID:</strong> {@node.id}</p>
      <p>
        Parent:
        <%= if Map.has_key?(@node.parent, :id) do %>
          <a href="#" phx-click="node_clicked" phx-value-id={@node.parent.id}>{@node.parent.id}</a>
        <% else %>
          None
        <% end %>
      </p>
      <p>
        Children:
        <%= for child <- assigns.node.children do %>
          <a href="#" phx-click="node_clicked" phx-value-id={child.id}>{child.id}</a>
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
