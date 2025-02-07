defmodule Dialectic.Responses.RequestQueue do
  alias Dialectic.Workers.DeepSeekWorker
  alias Dialectic.Workers.ClaudeWorker

  def add(question, to_node, graph) do
    %{
      question: question,
      to_node: to_node.id,
      graph: graph,
      module: Dialectic.Workers.ClaudeWorker
    }
    |> ClaudeWorker.new()
    |> Oban.insert()
  end

  def test() do
    IO.puts("Hello, world!")

    %{
      question: "What is dialectival materialism",
      to_node: "1",
      graph: "Bob",
      module: Dialectic.Workers.ClaudeWorker
    }
    |> ClaudeWorker.new()
    |> Oban.insert()
  end
end
