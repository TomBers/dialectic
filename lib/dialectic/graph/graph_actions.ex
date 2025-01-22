defmodule Dialectic.Graph.GraphActions do
  alias Dialectic.Graph.Vertex
  require DialecticWeb.CoreComponents

  def find_node(graph, id, default_node) do
    case Vertex.find_node_by_id(graph, id) do
      nil ->
        {default_node, Vertex.changeset(default_node)}

      node ->
        n = Vertex.add_relatives(graph, node)
        {n, Vertex.changeset(n)}
    end
  end
end
