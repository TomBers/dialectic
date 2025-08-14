defmodule Dialectic.Performance.Logger do
  @moduledoc """
  A dedicated logger for performance metrics.
  Writes performance-related logs to a separate file to avoid cluttering the main log.
  """

  require Logger

  @log_file "performance.log"
  @log_path Path.join("log", @log_file)

  @doc """
  Initializes the performance logger.
  Creates the log directory if it doesn't exist.
  """
  def init do
    File.mkdir_p!("log")

    File.write!(@log_path, "--- Performance Log Started at #{DateTime.utc_now()} ---\n", [:append])
  end

  @doc """
  Logs a performance metric with timestamp.
  """
  def log(message) do
    timestamp = DateTime.utc_now()
    formatted_message = "#{timestamp} - #{message}"

    # Write to the performance log file
    File.write!(@log_path, "#{formatted_message}\n", [:append])

    # Also log to console at debug level for development visibility
    Logger.debug(fn -> "PERF: #{message}" end)
  end

  @doc """
  Logs the start of a performance measurement section.
  Returns the start timestamp for later duration calculation.
  """
  def start(section_name) do
    timestamp = DateTime.utc_now()
    log("START: #{section_name}")
    timestamp
  end

  @doc """
  Logs the end of a performance measurement section with duration.
  """
  def finish(section_name, start_timestamp) do
    end_timestamp = DateTime.utc_now()
    duration_ms = DateTime.diff(end_timestamp, start_timestamp, :millisecond)
    log("FINISH: #{section_name} - Duration: #{duration_ms}ms")
    {end_timestamp, duration_ms}
  end

  @doc """
  Wraps a function call with performance logging.
  """
  def measure(section_name, func) when is_function(func, 0) do
    start_time = start(section_name)
    result = func.()
    {_end_time, _duration} = finish(section_name, start_time)
    result
  end
end
