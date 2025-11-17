defmodule Dialectic.LLM.Providers.Google do
  @moduledoc """
  Google (Gemini) provider implementation for the `Dialectic.LLM.Provider` behaviour.

  This module encapsulates all Gemini-specific configuration so the core
  streaming/dispatch code can remain provider-agnostic.

  Environment variables supported:

    Required:
      - GOOGLE_API_KEY                 (primary; falls back to GEMINI_API_KEY)

    Optional:
      - GOOGLE_MODEL                   (chat model; default: "gemini-1.5-flash")
      - GOOGLE_API_VERSION             ("v1" | "v1beta"; v1beta required for grounding)
      - GOOGLE_GROUNDING_ENABLE        (boolean; modern Gemini 2.5: %{enable: true})
      - GOOGLE_GROUNDING_LEGACY        (boolean; legacy Gemini 1.5: dynamic retrieval)
      - GOOGLE_GROUNDING_THRESHOLD     (float; default: 0.7, used for legacy dynamic_retrieval)
      - GOOGLE_THINKING_BUDGET         (integer; Gemini 2.5 thinking tokens)
      - GOOGLE_SAFETY                  (comma-separated list: "CATEGORY:THRESHOLD,...")
          Example:
            GOOGLE_SAFETY=HARM_CATEGORY_HATE_SPEECH:BLOCK_MEDIUM_AND_ABOVE,HARM_CATEGORY_DANGEROUS_CONTENT:BLOCK_LOW_AND_ABOVE
      - GOOGLE_CANDIDATE_COUNT         (integer > 0)
      - GOOGLE_CONNECT_TIMEOUT_MS      (integer; default 60000)
      - GOOGLE_RECEIVE_TIMEOUT_MS      (integer; default 300000)

  Notes:
  - If `GOOGLE_GROUNDING_ENABLE=true`, req_llm will auto-set API version to v1beta,
    but you can still explicitly select it via GOOGLE_API_VERSION.
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

  @impl true
  def connect_timeout do
    60_000
  end

  @impl true
  def receive_timeout do
    300_000
  end

  @impl true
  def tags, do: ["google", "gemini"]

  @impl true
  def finch_name, do: Dialectic.Finch
end
