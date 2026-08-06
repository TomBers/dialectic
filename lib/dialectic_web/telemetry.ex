defmodule DialecticWeb.Telemetry do
  use Supervisor

  import Ecto.Query
  import Telemetry.Metrics

  alias Dialectic.Repo
  alias Dialectic.Workers.LLMWorker

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    children = [
      # Telemetry poller will execute the given period measurements
      # every 10_000ms. Learn more here: https://hexdocs.pm/telemetry_metrics
      {:telemetry_poller, measurements: periodic_measurements(), period: 10_000}
      # Add reporters as children of your supervision tree.
      # {Telemetry.Metrics.ConsoleReporter, metrics: metrics()}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def metrics do
    [
      # Phoenix Metrics
      summary("phoenix.endpoint.start.system_time",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.endpoint.stop.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.start.system_time",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.exception.duration",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.stop.duration",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.socket_connected.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.channel_joined.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.channel_handled_in.duration",
        tags: [:event],
        unit: {:native, :millisecond}
      ),

      # LLM Metrics
      summary("dialectic.llm.queue_wait.duration",
        tags: [:provider, :outcome],
        unit: {:native, :millisecond}
      ),
      summary("dialectic.llm.time_to_first_token.duration",
        tags: [:provider, :outcome],
        unit: {:native, :millisecond}
      ),
      summary("dialectic.llm.job.duration",
        tags: [:provider, :outcome],
        unit: {:native, :millisecond}
      ),
      last_value("dialectic.llm.queue.queued"),
      last_value("dialectic.llm.queue.executing"),

      # Database Metrics
      summary("dialectic.repo.query.total_time",
        unit: {:native, :millisecond},
        description: "The sum of the other measurements"
      ),
      summary("dialectic.repo.query.decode_time",
        unit: {:native, :millisecond},
        description: "The time spent decoding the data received from the database"
      ),
      summary("dialectic.repo.query.query_time",
        unit: {:native, :millisecond},
        description: "The time spent executing the query"
      ),
      summary("dialectic.repo.query.queue_time",
        unit: {:native, :millisecond},
        description: "The time spent waiting for a database connection"
      ),
      summary("dialectic.repo.query.idle_time",
        unit: {:native, :millisecond},
        description:
          "The time the connection spent waiting before being checked out for the query"
      ),

      # VM Metrics
      summary("vm.memory.total", unit: {:byte, :kilobyte}),
      summary("vm.total_run_queue_lengths.total"),
      summary("vm.total_run_queue_lengths.cpu"),
      summary("vm.total_run_queue_lengths.io")
    ]
  end

  def measure_llm_queue do
    worker = Oban.Worker.to_string(LLMWorker)
    states = queue_states()

    counts =
      Repo.all(
        from job in Oban.Job,
          where: job.worker == ^worker and job.state in ^states,
          group_by: job.state,
          select: {job.state, count(job.id)}
      )
      |> Map.new()

    queued =
      Enum.sum([
        Map.get(counts, "available", 0),
        Map.get(counts, "scheduled", 0),
        Map.get(counts, "retryable", 0)
      ])

    emit_llm_queue_depth(queued, Map.get(counts, "executing", 0))
  rescue
    error ->
      require Logger
      Logger.warning("Unable to measure LLM queue depth: #{Exception.message(error)}")
      :ok
  catch
    :exit, _reason -> :ok
  end

  def emit_llm_queue_depth(queued, executing)
      when is_integer(queued) and queued >= 0 and is_integer(executing) and executing >= 0 do
    :telemetry.execute(
      [:dialectic, :llm, :queue],
      %{queued: queued, executing: executing},
      %{}
    )
  end

  defp periodic_measurements do
    [{__MODULE__, :measure_llm_queue, []}]
  end

  defp queue_states, do: ["available", "scheduled", "executing", "retryable"]
end
