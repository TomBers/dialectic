defmodule Dialectic.LLM.Providers.OpenAI do
  @moduledoc """
  OpenAI provider implementation for the `Dialictic.LLM.Provider` behaviour.

  This module encapsulates all OpenAI-specific configuration so the core
  streaming/dispatch code can remain provider-agnostic.

  Environment variables supported:

    - OPENAI_API_KEY                (required)
    - OPENAI_MODEL                  (optional, chat model name)
    - OPENAI_CHAT_MODEL             (optional, alias for model)
    - OPENAI_REASONING_EFFORT       (optional: "minimal" | "medium" | "maximal")
    - OPENAI_PARALLEL_TOOL_CALLS    (optional: boolean, "true"/"false"/"1"/"0")
    - OPENAI_CONNECT_TIMEOUT_MS     (optional: integer milliseconds)
    - OPENAI_RECEIVE_TIMEOUT_MS     (optional: integer milliseconds)

  Defaults:

    - model: "gpt-5-nano" (kept to match existing project defaults)
    - reasoning_effort: :minimal
    - openai_parallel_tool_calls: false
    - connect_timeout: 60_000 ms
    - receive_timeout: 300_000 ms
  """

  @behaviour Dialectic.LLM.Provider

  # -- Behaviour callbacks ------------------------------------------------------

  @impl true
  def id, do: :openai

  @impl true
  def model do
    System.get_env("OPENAI_MODEL") ||
      System.get_env("OPENAI_CHAT_MODEL") ||
      "gpt-5-nano"
  end

  @impl true
  def api_key do
    System.get_env("OPENAI_API_KEY")
  end

  @impl true
  def provider_options do
    []
    |> with_reasoning_effort_from_env()
    |> with_parallel_tool_calls_from_env()
  end

  @impl true
  def connect_timeout do
    env_int("OPENAI_CONNECT_TIMEOUT_MS", 60_000)
  end

  @impl true
  def receive_timeout do
    env_int("OPENAI_RECEIVE_TIMEOUT_MS", 300_000)
  end

  @impl true
  def tags, do: ["openai"]

  @impl true
  def finch_name, do: Dialectic.Finch

  # -- Internals ----------------------------------------------------------------

  defp with_reasoning_effort_from_env(opts) do
    case System.get_env("OPENAI_REASONING_EFFORT") do
      nil ->
        Keyword.put_new(opts, :reasoning_effort, :minimal)

      "" ->
        Keyword.put_new(opts, :reasoning_effort, :minimal)

      val ->
        Keyword.put(opts, :reasoning_effort, parse_reasoning_effort(val))
    end
  end

  defp with_parallel_tool_calls_from_env(opts) do
    case System.get_env("OPENAI_PARALLEL_TOOL_CALLS") do
      nil ->
        Keyword.put_new(opts, :openai_parallel_tool_calls, false)

      "" ->
        Keyword.put_new(opts, :openai_parallel_tool_calls, false)

      val ->
        Keyword.put(opts, :openai_parallel_tool_calls, parse_bool(val, false))
    end
  end

  defp parse_reasoning_effort(val) when is_binary(val) do
    case String.downcase(String.trim(val)) do
      "minimal" -> :minimal
      "medium" -> :medium
      "maximal" -> :maximal
      # Fallback to minimal to avoid surprising increases in latency/cost
      _ -> :minimal
    end
  end

  defp parse_bool(val, default) when is_binary(val) do
    case String.downcase(String.trim(val)) do
      "1" -> true
      "true" -> true
      "t" -> true
      "yes" -> true
      "y" -> true
      "on" -> true
      "0" -> false
      "false" -> false
      "f" -> false
      "no" -> false
      "n" -> false
      "off" -> false
      _ -> default
    end
  end

  defp env_int(name, default) do
    case System.get_env(name) do
      nil ->
        default

      "" ->
        default

      val ->
        case Integer.parse(val) do
          {i, ""} when i >= 0 -> i
          _ -> default
        end
    end
  end
end
