defmodule DialecticWeb.CombineComp do
  use DialecticWeb, :live_component

  alias DialecticWeb.CombinetMsgComp

  def update(assigns, socket) do
    possible_nodes =
      assigns.graph
      |> :digraph.vertices()
      |> Enum.map(fn id -> assigns.graph |> :digraph.vertex(id) |> elem(1) end)
      |> Enum.reject(&(&1 == assigns.node.id || &1.compound == true))

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
