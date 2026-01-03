defmodule Dialectic.LLM.Providers.Google do
  @moduledoc """
  Google (Gemini) provider for the `Dialectic.LLM.Provider` behaviour.

  Simplified configuration:
  - Required: GOOGLE_API_KEY (ReqLLM also supports GOOGLE_API_KEY automatically)
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
    "gemini-3-flash-preview"
  end

  @impl true
  def api_key do
    # ReqLLM expects Google credentials via `GOOGLE_API_KEY` (or config :req_llm, :google_api_key).
    # Keep this aligned so both streaming and non-streaming calls work consistently.
    System.get_env("GOOGLE_API_KEY")
  end

  @impl true
  def provider_options do
    []
  end
end
