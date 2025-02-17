defmodule Dialectic.Responses.NodeContext do
  def run do
    graph_id = "Satre"
    {_graph_struct, _graph} = GraphManager.get_graph(graph_id)
    GraphManager.build_context(graph_id, %{id: "6"})

    # IO.inspect(node.title)
  end
end
