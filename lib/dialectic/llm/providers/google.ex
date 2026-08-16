defmodule Dialectic.LLM.Providers.Google do
  @moduledoc """
  Google (Gemini) provider for the `Dialectic.LLM.Provider` behaviour.

  Default Gemini provider configuration:
  - Required: `GOOGLE_API_KEY`
  - Model: `gemini-3.7-flash`
  - Minimal thinking for lower latency
  - Google Search grounding for current, verifiable sources and links
  """

  @behaviour Dialectic.LLM.Provider

  # -- Behaviour callbacks ------------------------------------------------------

  @impl true
  def id, do: :google

  @impl true
  def model do
    "gemini-3.7-flash"
  end

  @impl true
  def api_key do
    System.get_env("GOOGLE_API_KEY")
  end

  @impl true
  def provider_options, do: provider_options(:simple)

  def provider_options(mode) do
    thinking_level =
      case mode do
        mode when mode in [:simple, :high_school] -> "low"
        :expert -> "high"
        _ -> "medium"
      end

    [
      google_thinking_level: thinking_level,
      google_grounding: %{enable: true}
    ]
  end
end
