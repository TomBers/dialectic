defmodule DialecticWeb.NodeComponent do
  use DialecticWeb, :live_component
  # alias Dialectic.Graph.Vertex

  def render(assigns) do
    ~H"""
    <div class="node">
      <h2>Node</h2>
      <p><strong>ID:</strong> {@node.name}</p>
      <p><strong>Description:</strong> {@node.description}</p>
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
