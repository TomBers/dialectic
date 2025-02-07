defmodule Dialectic.Responses.RequestQueue do
  # alias Dialectic.Workers.DeepSeekWorker
  # alias Dialectic.Workers.ClaudeWorker
  alias Dialectic.Workers.GeminiWorker
  # alias Dialectic.Workers.OpenAIWorker

  def add(question, to_node, graph) do
    %{
      question: question,
      to_node: to_node.id,
      graph: graph,
      module: Dialectic.Workers.GeminiWorker
    }
    |> GeminiWorker.new()
    |> Oban.insert()
  end

  def test() do
    IO.puts("Hello, world!")

    %{
      question: "What is the Gemini model?",
      to_node: "1",
      graph: "Bob",
      module: Dialectic.Workers.GeminiWorker
    }
    |> GeminiWorker.new()
    |> Oban.insert()
  end
end
