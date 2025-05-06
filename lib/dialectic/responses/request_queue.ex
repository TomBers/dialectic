defmodule Dialectic.Responses.RequestQueue do
  alias Dialectic.Workers.DeepSeekWorker
  alias Dialectic.Workers.ClaudeWorker
  alias Dialectic.Workers.GeminiWorker
  alias Dialectic.Workers.OpenAIWorker
  alias Dialectic.Workers.LocalWorker

  # Define the implementation based on compile-time environment
  if Mix.env() == :test do
    # Test environment uses local model
    def add(question, to_node, graph) do
      params = %{
        question: question,
        to_node: to_node.id,
        graph: graph,
        module: nil
      }
      run_local(params)
    end
  else
    # Non-test environments use OpenAI
    def add(question, to_node, graph) do
      params = %{
        question: question,
        to_node: to_node.id,
        graph: graph,
        module: nil
      }
      run_openai(params)
    end
  end

  def run_local(params) do
    %{
      params
      | module: Dialectic.Workers.LocalWorker
    }
    |> LocalWorker.new()
    |> Oban.insert()
  end

  def run_deepseek(params) do
    %{
      params
      | module: Dialectic.Workers.DeepSeekWorker
    }
    |> DeepSeekWorker.new()
    |> Oban.insert()
  end

  def run_claude(params) do
    %{
      params
      | module: Dialectic.Workers.ClaudeWorker
    }
    |> ClaudeWorker.new()
    |> Oban.insert()
  end

  def run_gemini(params) do
    %{
      params
      | module: Dialectic.Workers.GeminiWorker
    }
    |> GeminiWorker.new()
    |> Oban.insert()
  end

  def run_openai(params) do
    %{
      params
      | module: Dialectic.Workers.OpenAIWorker
    }
    |> OpenAIWorker.new()
    |> Oban.insert()
  end

  def test() do
    params = %{
      question: "What is a Body without organs?",
      to_node: "1",
      graph: "Bob",
      module: nil
    }

    run_deepseek(params)
    run_claude(params)
    run_gemini(params)
    run_openai(params)
  end
end
