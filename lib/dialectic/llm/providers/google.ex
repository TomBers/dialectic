defmodule Dialectic.LLM.Providers.Google do
  @moduledoc """
  Google (Gemini) provider for the `Dialectic.LLM.Provider` behaviour.

  Default Gemini provider configuration:
  - Required: `GOOGLE_API_KEY`
  - Model: `gemini-3.5-flash-lite`
  - Minimal thinking for lower latency
  - Google Search grounding for current, verifiable sources and links
  """

  @behaviour Dialectic.LLM.Provider

  # -- Behaviour callbacks ------------------------------------------------------

  @impl true
  def id, do: :google

  @impl true
  def model do
    "gemini-3.5-flash-lite"
  end

  @impl true
  def api_key do
    System.get_env("GOOGLE_API_KEY")
  end

  @impl true
  def provider_options, do: provider_options(:high_school)

  def provider_options(mode) do
    thinking_level =
      case mode do
        :high_school -> "minimal"
        :expert -> "medium"
        _ -> "low"
      end

    [
      google_thinking_level: thinking_level,
      google_grounding: %{enable: mode in [:university, :expert]}
    ]
  end
end
