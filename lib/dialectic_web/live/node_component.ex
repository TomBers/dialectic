defmodule DialecticWeb.NodeComponent do
  use DialecticWeb, :live_component
  # alias Dialectic.Graph.Vertex

  def render(assigns) do
    ~H"""
    <div class="node">
      <h2>Node</h2>
      <p><strong>ID:</strong> {@node.id}</p>
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
