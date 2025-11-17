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
    System.get_env("GOOGLE_MODEL") ||
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
    |> with_grounding_from_env()
    |> with_api_version_from_env()
    |> with_thinking_budget_from_env()
    |> with_safety_settings_from_env()
    |> with_candidate_count_from_env()
  end

  @impl true
  def connect_timeout do
    env_int("GOOGLE_CONNECT_TIMEOUT_MS", 60_000)
  end

  @impl true
  def receive_timeout do
    env_int("GOOGLE_RECEIVE_TIMEOUT_MS", 300_000)
  end

  @impl true
  def tags, do: ["google", "gemini"]

  @impl true
  def finch_name, do: Dialectic.Finch

  # -- Internals ----------------------------------------------------------------

  defp with_grounding_from_env(opts) do
    cond do
      parse_bool(System.get_env("GOOGLE_GROUNDING_LEGACY"), false) ->
        threshold =
          case System.get_env("GOOGLE_GROUNDING_THRESHOLD") do
            nil -> 0.7
            "" -> 0.7
            v -> parse_float(v, 0.7)
          end

        Keyword.put(opts, :google_grounding, %{
          dynamic_retrieval: %{
            mode: "MODE_DYNAMIC",
            dynamic_threshold: threshold
          }
        })

      parse_bool(System.get_env("GOOGLE_GROUNDING_ENABLE"), false) ->
        Keyword.put(opts, :google_grounding, %{enable: true})

      true ->
        opts
    end
  end

  defp with_api_version_from_env(opts) do
    case System.get_env("GOOGLE_API_VERSION") do
      "v1" -> Keyword.put(opts, :google_api_version, "v1")
      "v1beta" -> Keyword.put(opts, :google_api_version, "v1beta")
      _ -> opts
    end
  end

  defp with_thinking_budget_from_env(opts) do
    case System.get_env("GOOGLE_THINKING_BUDGET") do
      nil ->
        opts

      "" ->
        opts

      v ->
        case Integer.parse(v) do
          {i, ""} when i >= 0 -> Keyword.put(opts, :google_thinking_budget, i)
          _ -> opts
        end
    end
  end

  defp with_candidate_count_from_env(opts) do
    case System.get_env("GOOGLE_CANDIDATE_COUNT") do
      nil ->
        opts

      "" ->
        opts

      v ->
        case Integer.parse(v) do
          {i, ""} when i > 0 -> Keyword.put(opts, :google_candidate_count, i)
          _ -> opts
        end
    end
  end

  defp with_safety_settings_from_env(opts) do
    case System.get_env("GOOGLE_SAFETY") do
      nil ->
        opts

      "" ->
        opts

      str ->
        case parse_safety_settings(str) do
          [] -> opts
          list -> Keyword.put(opts, :google_safety_settings, list)
        end
    end
  end

  defp parse_safety_settings(str) when is_binary(str) do
    str
    |> String.split(",", trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.map(fn pair ->
      case String.split(pair, ":", parts: 2) do
        [category, threshold] ->
          %{
            category: String.trim(category),
            threshold: String.trim(threshold)
          }

        _ ->
          nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp parse_bool(nil, default), do: default
  defp parse_bool("", default), do: default

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

      v ->
        case Integer.parse(v) do
          {i, ""} when i >= 0 -> i
          _ -> default
        end
    end
  end

  defp parse_float(v, default) do
    case Float.parse(v) do
      {f, ""} -> f
      _ -> default
    end
  end
end
