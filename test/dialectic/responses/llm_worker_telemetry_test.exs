defmodule Dialectic.Responses.LLMWorkerTelemetryTest do
  use ExUnit.Case, async: true

  alias Dialectic.Workers.LLMWorker
  alias DialecticWeb.Telemetry, as: WebTelemetry

  @events [
    [:dialectic, :llm, :queue_wait],
    [:dialectic, :llm, :time_to_first_token],
    [:dialectic, :llm, :job],
    [:dialectic, :llm, :queue]
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

  test "retries partial responses instead of treating them as completed duplicates" do
    partial_response = String.duplicate("partial", 10)

    assert LLMWorker.skip_existing_response?(1, partial_response)
    refute LLMWorker.skip_existing_response?(2, partial_response)
    refute LLMWorker.skip_existing_response?(1, "short")
  end

  test "batches stream updates while flushing the first chunk immediately" do
    assert LLMWorker.should_flush_stream?(true, 1, 0)
    refute LLMWorker.should_flush_stream?(false, 199, 499)
    refute LLMWorker.should_flush_stream?(false, 200, 99)
    assert LLMWorker.should_flush_stream?(false, 200, 100)
    assert LLMWorker.should_flush_stream?(false, 1, 500)
  end

  test "uses the retry schedule as the queue-wait reference after the first attempt" do
    inserted_at = ~U[2026-08-06 12:00:00.000000Z]
    scheduled_at = ~U[2026-08-06 12:01:00.000000Z]

    assert LLMWorker.queue_reference_time(1, inserted_at, scheduled_at) == inserted_at
    assert LLMWorker.queue_reference_time(2, inserted_at, scheduled_at) == scheduled_at
    assert LLMWorker.queue_reference_time(2, inserted_at, nil) == inserted_at
  end

  test "emits low-cardinality timing event metadata without request identifiers" do
    LLMWorker.emit_queue_wait(11, :openai, :error)
    LLMWorker.emit_time_to_first_token(22, :google)
    LLMWorker.emit_job_duration(33, :openai, :discard)
    WebTelemetry.emit_llm_queue_depth(4, 2)

    assert_receive {:telemetry_event, [:dialectic, :llm, :queue_wait], %{duration: 11},
                    %{provider: :openai, outcome: :error}}

    assert_receive {:telemetry_event, [:dialectic, :llm, :time_to_first_token], %{duration: 22},
                    %{provider: :google, outcome: :success}}

    assert_receive {:telemetry_event, [:dialectic, :llm, :job], %{duration: 33},
                    %{provider: :openai, outcome: :discard}}

    assert_receive {:telemetry_event, [:dialectic, :llm, :queue], %{queued: 4, executing: 2}, %{}}
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

    for name <- [
          [:dialectic, :llm, :queue, :queued],
          [:dialectic, :llm, :queue, :executing]
        ] do
      assert %Telemetry.Metrics.LastValue{} = Enum.find(metrics, &(&1.name == name))
    end
  end
end
