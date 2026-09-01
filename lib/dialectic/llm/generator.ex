defmodule Dialectic.LLM.Generator do
  @moduledoc """
  Unified interface for non-streaming LLM generation.
  """
  require Logger
  alias Dialectic.LLM.Provider

  @doc """
  Generates a response for a given prompt (and optional system prompt).

  ## Options
  - `system_prompt` (string): Optional system instructions.
  - `model` (string): Override the configured Gemini model.
  """
  def generate(prompt, opts \\ []) do
    system_prompt = Keyword.get(opts, :system_prompt)
    provider_mod = Dialectic.LLM.Providers.Google

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
    {_connect_timeout, receive_timeout} = Provider.timeouts(provider_mod)
    provider_options = provider_mod.provider_options()

    req_http_options = Application.get_env(:dialectic, :llm_req_options, [])

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

  defp extract_text(%ReqLLM.Response{} = resp), do: ReqLLM.Response.text(resp)
  defp extract_text(text) when is_binary(text), do: text
  defp extract_text(other), do: to_string(other || "")
end
