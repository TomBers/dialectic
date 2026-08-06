defmodule Dialectic.Responses.LLMWorkerTelemetryTest do
  use ExUnit.Case, async: true

  alias Dialectic.Workers.LLMWorker
  alias DialecticWeb.Telemetry, as: WebTelemetry

  @events [
    [:dialectic, :llm, :queue_wait],
    [:dialectic, :llm, :time_to_first_token],
    [:dialectic, :llm, :job]
  ]

  setup do
    handler_id = {__MODULE__, self(), make_ref()}

    :ok =
      :telemetry.attach_many(
        handler_id,
        @events,
        fn event, measurements, metadata, pid ->
          send(pid, {:telemetry_event, event, measurements, metadata})
        end,
        self()
      )

    on_exit(fn -> :telemetry.detach(handler_id) end)
  end

  test "calculates queue wait from DateTime microseconds in native units" do
    inserted_at = ~U[2026-08-06 12:00:00.123456Z]
    wait_microseconds = 1_234_567
    started_at = DateTime.to_unix(inserted_at, :microsecond) + wait_microseconds

    duration = LLMWorker.queue_wait_duration(inserted_at, started_at)

    assert System.convert_time_unit(duration, :native, :microsecond) == wait_microseconds
    assert LLMWorker.queue_wait_duration(inserted_at, started_at - wait_microseconds - 1) == 0
    assert LLMWorker.queue_wait_duration(nil, started_at) == nil
  end

  test "emits low-cardinality timing event metadata without request identifiers" do
    LLMWorker.emit_queue_wait(11, :openai, :error)
    LLMWorker.emit_time_to_first_token(22, :google)
    LLMWorker.emit_job_duration(33, :openai, :discard)

    assert_receive {:telemetry_event, [:dialectic, :llm, :queue_wait], %{duration: 11},
                    %{provider: :openai, outcome: :error}}

    assert_receive {:telemetry_event, [:dialectic, :llm, :time_to_first_token], %{duration: 22},
                    %{provider: :google, outcome: :success}}

    assert_receive {:telemetry_event, [:dialectic, :llm, :job], %{duration: 33},
                    %{provider: :openai, outcome: :discard}}
  end

  test "registers all LLM timing summaries with native-to-millisecond conversion" do
    metrics = WebTelemetry.metrics()

    for name <- [
          [:dialectic, :llm, :queue_wait, :duration],
          [:dialectic, :llm, :time_to_first_token, :duration],
          [:dialectic, :llm, :job, :duration]
        ] do
      metric = Enum.find(metrics, &(&1.name == name))

      assert %Telemetry.Metrics.Summary{} = metric
      assert metric.tags == [:provider, :outcome]
      assert metric.unit == :millisecond
    end
  end
end
