defmodule Dialectic.LLM.Providers.Google do
  @moduledoc """
  Google (Gemini) provider for the `Dialectic.LLM.Provider` behaviour.

  Simplified configuration:
  - Required: GOOGLE_API_KEY
  - Hardcoded model: "gemini-3-flash-preview"
  - Optional: GEMINI_THINKING_LEVEL (minimal, low, medium, high) - defaults to "low"

  The thinking level controls how much reasoning the model performs:
  - "minimal": Minimizes latency (thinking budget: 512 tokens)
  - "low": Minimizes latency and cost for simple tasks (thinking budget: 2048 tokens, default)
  - "medium": Balanced thinking for most tasks (thinking budget: 8192 tokens)
  - "high": Maximizes reasoning depth (thinking budget: -1 for dynamic)

  Note: Gemini 3 models accept thinkingBudget for backward compatibility.
  We map thinking levels to appropriate token budgets.
  """

  @behaviour Dialectic.LLM.Provider

  # -- Behaviour callbacks ------------------------------------------------------

  @impl true
  def id, do: :google

  @impl true
  def model do
    "gemini-3-flash-preview"
  end

  @impl true
  def api_key do
    System.get_env("GOOGLE_API_KEY")
  end

  @impl true
  def provider_options do
    thinking_level = System.get_env("GEMINI_THINKING_LEVEL", "minimal")
    thinking_budget = thinking_level_to_budget(thinking_level)

    [
      google_thinking_budget: thinking_budget
    ]
  end

  # Map thinking levels to token budgets
  # Gemini 3 Flash supports budgets from 0 to 24576
  # -1 enables dynamic thinking (default high)
  defp thinking_level_to_budget("minimal"), do: 512
  defp thinking_level_to_budget("low"), do: 2048
  defp thinking_level_to_budget("medium"), do: 8192
  defp thinking_level_to_budget("high"), do: -1
  # Fallback to low for unknown values
  defp thinking_level_to_budget(_), do: 2048
end
