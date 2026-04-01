defmodule Dialectic.LLM.Providers.Google do
  @moduledoc """
  Google (Gemini) provider for the `Dialectic.LLM.Provider` behaviour.

  Simplified configuration:
  - Required: GEMINI_API_KEY or GOOGLE_API_KEY (checks both)
  - Hardcoded model: "gemini-3-flash-preview"
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
    "gemini-3-flash-preview"
  end

  @impl true
  def api_key do
    # Check both GEMINI_API_KEY (ReqLLM standard) and GOOGLE_API_KEY (legacy)
    System.get_env("GEMINI_API_KEY") || System.get_env("GOOGLE_API_KEY")
  end

  @impl true
  def provider_options do
    []
  end
end
