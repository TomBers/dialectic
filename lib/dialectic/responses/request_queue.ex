defmodule Dialectic.Responses.RequestQueue do
  alias Dialectic.Workers.DeepSeekWorker

  def add(question, to_node, graph) do
    %{question: question, to_node: to_node.id, graph: graph}
    |> DeepSeekWorker.new()
    |> Oban.insert()
  end
end
