defmodule Dialectic.Responses.RequestQueue do
  alias Dialectic.Workers.LLMWorker
  alias Dialectic.Workers.LocalWorker
  require Logger

  # Define the implementation based on compile-time environment
  if Mix.env() == :test do
    # Test environment uses local model
    def add(instruction, system_prompt, to_node, graph, live_view_topic) do
      params = %{
        instruction: instruction,
        system_prompt: system_prompt,
        question: instruction,
        to_node: to_node.id,
        graph: graph,
        module: nil,
        live_view_topic: live_view_topic
      }

      run_local(params)
    end
  else
    # Non-test environments use LLMWorker
    def add(instruction, system_prompt, to_node, graph, live_view_topic) do
      params = %{
        instruction: instruction,
        system_prompt: system_prompt,
        question: instruction,
        to_node: to_node.id,
        graph: graph,
        module: nil,
        live_view_topic: live_view_topic
      }

      run_llm(params)
    end
  end

  def run_local(params) do
    %{
      params
      | module: Dialectic.Workers.LocalWorker
    }
    |> LocalWorker.new(
      unique: [
        fields: [:args, :worker],
        keys: [:graph, :to_node],
        period: 60,
        states: [:available, :scheduled, :executing, :retryable]
      ]
    )
    |> Oban.insert()
  end

  def run_llm(params) do
    %{
      params
      | module: Dialectic.Workers.LLMWorker
    }
    |> LLMWorker.new(
      priority: 0,
      max_attempts: 3,
      tags: ["llm"],
      unique: [
        fields: [:args, :worker],
        keys: [:graph, :to_node],
        period: 60,
        states: [:available, :scheduled, :executing, :retryable]
      ]
    )
    |> Oban.insert()
  end
end
