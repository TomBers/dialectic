defmodule DialecticWeb.CombineComp do
  use DialecticWeb, :live_component

  alias DialecticWeb.CombinetMsgComp

  def update(assigns, socket) do
    graph_id = assigns[:graph_id] || get_in(assigns, [:graph_struct, :title])

    possible_nodes =
      GraphManager.vertices(graph_id)
      |> Enum.map(fn vid -> GraphManager.vertex_label(graph_id, vid) end)
      |> Enum.reject(&is_nil/1)
      |> Enum.reject(&(&1.id == assigns.node.id or Map.get(&1, :compound, false) == true))

    {:ok, assign(socket, possible_nodes: possible_nodes)}
  end

  def render(assigns) do
    ~H"""
    <div class="node-list">
      <%= for node <- @possible_nodes do %>
        <.live_component module={CombinetMsgComp} node={node} id={node.id <>"_combine" } />
      <% end %>
    </div>
    """
  end
end
