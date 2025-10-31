defmodule Dialectic.Responses.RequestQueue do
  alias Dialectic.Workers.DeepSeekWorker
  alias Dialectic.Workers.ClaudeWorker
  alias Dialectic.Workers.GeminiWorker
  alias Dialectic.Workers.OpenAIWorker
  alias Dialectic.Workers.LocalWorker
  require Logger

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
    # Non-test environments use OpenAI, but fallback to LocalWorker in dev when API key is missing
    def add(question, to_node, graph, live_view_topic) do
      params = %{
        question: question,
        to_node: to_node.id,
        graph: graph,
        module: nil,
        live_view_topic: live_view_topic
      }

      env_key = System.get_env("OPENAI_API_KEY")
      missing_key? = is_nil(env_key) or String.trim(env_key) == ""

      if missing_key? do
        Logger.info("OPENAI_API_KEY missing; falling back to local model")
        run_local(params)
      else
        # Route selection responses to lower-priority path when class is "explain"
        is_selection =
          case to_node do
            %{} = node -> Map.get(node, :class) == "explain"
            _ -> false
          end

        if is_selection do
          Logger.info("Enqueue OpenAI selection job for graph=#{graph} node=#{to_node.id}")
          run_openai_selection(params)
        else
          Logger.info("Enqueue OpenAI job for graph=#{graph} node=#{to_node.id}")
          run_openai(params)
        end
      end
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
    |> OpenAIWorker.new(priority: 0, max_attempts: 3, tags: ["openai"])
    |> Oban.insert()
  end

  def run_openai_selection(params) do
    %{
      params
      | module: Dialectic.Workers.OpenAIWorker
    }
    |> OpenAIWorker.new(priority: 5, max_attempts: 3, tags: ["openai", "selection"])
    |> Oban.insert()
  end

  def test() do
    params = %{
      question: "What is a Body without organs?",
      to_node: "1",
      graph: "Bob",
      module: nil,
      live_view_topic: "test_topic"
    }

    run_deepseek(params)
    run_claude(params)
    run_gemini(params)
    run_openai(params)
    :ok
  end
end
