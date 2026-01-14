defmodule Dialectic.LLM.Providers.OpenAI do
  @moduledoc """
  OpenAI provider implementation for the `Dialectic.LLM.Provider` behaviour.

  Simplified configuration:
  - Required: OPENAI_API_KEY
  - Hardcoded model: "gpt-5-nano"
  - Hardcoded options: reasoning_effort: :minimal, openai_parallel_tool_calls: false
  """

  @behaviour Dialectic.LLM.Provider

  @impl true
  def id, do: :openai

  @impl true
  def model, do: "gpt-5-nano"

  @impl true
  def api_key, do: System.get_env("OPENAI_API_KEY")

  @impl true
  def provider_options do
    [
      openai_parallel_tool_calls: false
    ]
  end
end
