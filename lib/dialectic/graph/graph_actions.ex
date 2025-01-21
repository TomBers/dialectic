defmodule Dialectic.Graph.GraphActions do
  alias Dialectic.Graph.Vertex

  def find_node(graph, id) do
    node = Vertex.find_node_by_id(graph, id)
    node = Vertex.add_relatives(graph, node)
    {node, Vertex.changeset(node)}
  end
end
