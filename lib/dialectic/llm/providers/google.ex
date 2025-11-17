defmodule Dialectic.LLM.Providers.Google do
  @moduledoc """
  Google (Gemini) provider for the `Dialectic.LLM.Provider` behaviour.

  Simplified configuration:
  - Required: GOOGLE_API_KEY (falls back to GEMINI_API_KEY)
  - Hardcoded model: "gemini-2.0-flash-lite"
  - provider_options: []

  Note: We intentionally keep this minimal to reduce surface area. Add environment-driven
  configuration only when you need it.
  """

  @behaviour Dialectic.LLM.Provider

  # -- Behaviour callbacks ------------------------------------------------------

  @impl true
  def id, do: :google

  @impl true
  def model do
    "gemini-2.0-flash-lite"
  end

  @impl true
  def api_key do
    System.get_env("GOOGLE_API_KEY") ||
      System.get_env("GEMINI_API_KEY")
  end

  @impl true
  def provider_options do
    []
  end
end
