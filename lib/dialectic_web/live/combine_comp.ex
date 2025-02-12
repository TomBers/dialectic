defmodule DialecticWeb.CombineComp do
  use DialecticWeb, :live_component

  alias DialecticWeb.ChatMsgComp

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
        <.live_component
          module={ChatMsgComp}
          show_user_controls={false}
          node={node}
          id={node.id <>"_combine" }
        />
      <% end %>
    </div>
    """
  end
end
