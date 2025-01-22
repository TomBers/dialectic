defmodule DialecticWeb.CombineComp do
  use DialecticWeb, :live_component

  def update(assigns, socket) do
    # IO.inspect(assigns)
    possible_nodes =
      assigns.graph
      |> :digraph.vertices()
      |> Enum.reject(&(&1 == assigns.node.id))
      |> Enum.map(fn id -> assigns.graph |> :digraph.vertex(id) |> elem(1) end)

    {:ok, assign(socket, possible_nodes: possible_nodes)}
  end

  def render(assigns) do
    ~H"""
    <div class="node-list">
      <%= for node <- @possible_nodes do %>
        <div class="node">
          <h2>{node.id}</h2>
          <div class="proposition">{raw(node.proposition)}</div>
        </div>
      <% end %>
    </div>
    """
  end
end
