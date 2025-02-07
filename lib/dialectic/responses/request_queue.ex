defmodule Dialectic.Responses.RequestQueue do
  @model Application.compile_env(:dialectic, :model_to_use, "local")

  alias Dialectic.Workers.DeepSeekWorker
  alias Dialectic.Workers.ClaudeWorker
  alias Dialectic.Workers.GeminiWorker
  alias Dialectic.Workers.OpenAIWorker

  def add(question, to_node, graph) do
    params = %{
      question: question,
      to_node: to_node.id,
      graph: graph,
      module: nil
    }

    case @model do
      "Deepseek" -> run_deepseek(params)
      "Claude" -> run_claude(params)
      "Gemini" -> run_gemini(params)
      "OpenAI" -> run_openai(params)
      _ -> run_local(params)
    end
  end

  def run_local(%{
        question: question,
        to_node: to_node,
        graph: graph
      }) do
    Phoenix.PubSub.broadcast(
      Dialectic.PubSub,
      graph,
      {:stream_chunk, question, :node_id, to_node}
    )
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
      question: "Can you write a short summary of Anti-Oedipus?",
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
