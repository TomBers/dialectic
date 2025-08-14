defmodule Dialectic.Responses.RequestQueue do
  alias Dialectic.Workers.DeepSeekWorker
  alias Dialectic.Workers.ClaudeWorker
  alias Dialectic.Workers.GeminiWorker
  alias Dialectic.Workers.OpenAIWorker
  alias Dialectic.Workers.LocalWorker
  alias Dialectic.Performance.Logger, as: PerfLogger

  # Define the implementation based on compile-time environment
  if Mix.env() == :test do
    # Test environment uses local model
    def add(question, to_node, graph, live_view_topic) do
      IO.inspect("Ask Model: #{DateTime.utc_now()}")
      PerfLogger.log("Ask Model initiated")

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
      IO.inspect("Ask Model: #{DateTime.utc_now()}")
      PerfLogger.log("Ask Model initiated")

      params = %{
        question: question,
        to_node: to_node.id,
        graph: graph,
        module: nil,
        live_view_topic: live_view_topic
      }

      # Use optimized enqueuing for OpenAI to improve performance
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
    insert_start = DateTime.utc_now()
    Dialectic.Performance.Logger.log("Oban.insert start")

    # Create the job
    job_creation_start = DateTime.utc_now()

    job =
      %{
        params
        | module: Dialectic.Workers.OpenAIWorker
      }
      |> OpenAIWorker.new(priority: 0, max_attempts: 3, tags: ["openai"])

    job_creation_end = DateTime.utc_now()
    job_creation_time_ms = DateTime.diff(job_creation_end, job_creation_start, :millisecond)
    Dialectic.Performance.Logger.log("Oban job creation (took #{job_creation_time_ms}ms)")

    # Insert the job
    insert_db_start = DateTime.utc_now()
    result = Oban.insert(job)
    insert_db_end = DateTime.utc_now()

    insert_db_time_ms = DateTime.diff(insert_db_end, insert_db_start, :millisecond)
    total_insert_time_ms = DateTime.diff(insert_db_end, insert_start, :millisecond)

    Dialectic.Performance.Logger.log(
      "Oban.insert database operation (took #{insert_db_time_ms}ms)"
    )

    Dialectic.Performance.Logger.log(
      "Oban.insert completed (total time: #{total_insert_time_ms}ms)"
    )

    result
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
