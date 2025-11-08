defmodule Dialectic.Responses.RequestQueue do
  alias Dialectic.Workers.OpenAIWorker
  alias Dialectic.Workers.LocalWorker

  # Define the implementation based on compile-time environment
  if Mix.env() == :test do
    # Test environment uses local model
    def add(question, to_node, graph, live_view_topic) do
      params = %{
        question: question,
        to_node: to_node.id,
        graph: graph,
        module: nil,
        live_view_topic: live_view_topic
      }

      run_local(params)
    end
  else
    # Non-test environments use OpenAI
    def add(question, to_node, graph, live_view_topic) do
      params = %{
        question: question,
        to_node: to_node.id,
        graph: graph,
        module: nil,
        live_view_topic: live_view_topic
      }

      # Route selection responses to lower-priority path when class is "explain"
      is_selection =
        case to_node do
          %{} = node -> Map.get(node, :class) == "explain"
          _ -> false
        end

      if is_selection do
        run_openai_selection(params)
      else
        run_openai(params)
      end
    end
  end

  def run_local(params) do
    %{
      params
      | module: Dialectic.Workers.LocalWorker
    }
    |> LocalWorker.new(
      unique: [
        fields: [:args, :worker, :queue],
        keys: [:graph, :to_node],
        period: 60,
        states: [:available, :scheduled, :executing, :retryable]
      ]
    )
    |> Oban.insert()
  end

  def run_openai(params) do
    %{
      params
      | module: Dialectic.Workers.OpenAIWorker
    }
    |> OpenAIWorker.new(
      priority: 0,
      max_attempts: 3,
      tags: ["openai"],
      unique: [
        fields: [:args, :worker, :queue],
        keys: [:graph, :to_node],
        period: 60,
        states: [:available, :scheduled, :executing, :retryable]
      ]
    )
    |> Oban.insert()
  end

  def run_openai_selection(params) do
    %{
      params
      | module: Dialectic.Workers.OpenAIWorker
    }
    |> OpenAIWorker.new(
      priority: 5,
      max_attempts: 3,
      tags: ["openai", "selection"],
      unique: [
        fields: [:args, :worker, :queue],
        keys: [:graph, :to_node],
        period: 60,
        states: [:available, :scheduled, :executing, :retryable]
      ]
    )
    |> Oban.insert()
  end
end
