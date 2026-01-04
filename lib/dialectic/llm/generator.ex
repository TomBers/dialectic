defmodule Dialectic.LLM.Generator do
  @moduledoc """
  Unified interface for non-streaming LLM generation.
  Handles provider selection, context building, and response extraction.
  """
  require Logger
  alias Dialectic.LLM.Provider

  @doc """
  Generates a response for a given prompt (and optional system prompt).

  ## Options
  - `system_prompt` (string): Optional system instructions.
  - `model` (string): Override the provider's default model (e.g. "gemini-2.5-flash-lite").
  - `provider` (atom): Override the default provider (e.g. :google, :openai).
  """
  def generate(prompt, opts \\ []) do
    system_prompt = Keyword.get(opts, :system_prompt)
    provider_id = Keyword.get(opts, :provider, default_provider_id())

    provider_mod = get_provider_module(provider_id)

    # Allow model override, else default from provider
    model_spec =
      case Keyword.get(opts, :model) do
        m when is_binary(m) -> {provider_mod.id(), [model: m]}
        _ -> Provider.model_spec(provider_mod)
      end

    messages =
      if system_prompt do
        [ReqLLM.Context.system(system_prompt), ReqLLM.Context.user(prompt)]
      else
        [ReqLLM.Context.user(prompt)]
      end

    ctx = ReqLLM.Context.new(messages)

    # Prepare options
    {connect_timeout, receive_timeout} = Provider.timeouts(provider_mod)
    provider_options = provider_mod.provider_options()

    # Handle Authentication:
    # 1. Check if the Provider abstraction has a key.
    # 2. If so, pass it in a way `ReqLLM` / `Req` accepts.
    #    - Google: needs `google_api_key`. Passing via `req_http_options` or config.
    #    - OpenAI: needs `auth: {:bearer, key}` or `api_key` (handled by ReqLLM adapter).
    req_http_options = [connect_options: [timeout: connect_timeout]]

    req_http_options =
      case Provider.api_key(provider_mod) do
        {:ok, key} ->
          case provider_mod.id() do
            :google -> Keyword.put(req_http_options, :google_api_key, key)
            _ -> Keyword.put(req_http_options, :auth, {:bearer, key})
          end

        _ ->
          # If not returned by Provider, assume it's in App config or Env
          req_http_options
      end

    case ReqLLM.generate_text(
           model_spec,
           ctx,
           provider_options: provider_options,
           req_http_options: req_http_options,
           receive_timeout: receive_timeout
         ) do
      {:ok, resp} ->
        {:ok, extract_text(resp)}

      {:error, reason} ->
        Logger.error("LLM Generation Error: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp default_provider_id do
    case System.get_env("LLM_PROVIDER") do
      "google" -> :google
      "gemini" -> :google
      _ -> :openai
    end
  end

  defp get_provider_module(:google), do: Dialectic.LLM.Providers.Google
  defp get_provider_module(:openai), do: Dialectic.LLM.Providers.OpenAI
  defp get_provider_module(_), do: Dialectic.LLM.Providers.OpenAI

  defp extract_text(%ReqLLM.Response{} = resp), do: ReqLLM.Response.text(resp)
  defp extract_text(text) when is_binary(text), do: text
  defp extract_text(other), do: to_string(other || "")
end
