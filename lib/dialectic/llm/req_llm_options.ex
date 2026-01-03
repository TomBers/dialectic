defmodule Dialectic.LLM.ReqLLMOptions do
  @moduledoc """
  Small helpers for building `ReqLLM` options consistently across the codebase.

  Why this exists:

  `ReqLLM` validates provider-specific credential option names. For example:

    - OpenAI expects `:openai_api_key`
    - Google (Gemini) expects `:google_api_key`

  Some of our older streaming calls passed a generic `:api_key` option, but
  non-streaming calls are stricter and will raise if the provider-specific key
  is not used.

  Use `credential_opts/2` to build the correct keyword list, and then merge it
  into your ReqLLM call options.
  """

  @typedoc "A module implementing `Dialectic.LLM.Provider`"
  @type provider_module :: module()

  @doc """
  Returns provider-specific credential options for ReqLLM.

  ## Examples

      opts = Dialectic.LLM.ReqLLMOptions.credential_opts(Dialectic.LLM.Providers.OpenAI, key)
      ReqLLM.generate_text(model_spec, ctx, opts)

      opts = Dialectic.LLM.ReqLLMOptions.credential_opts(Dialectic.LLM.Providers.Google, key)
      ReqLLM.stream_text(model_spec, ctx, opts)

  """
  @spec credential_opts(provider_module(), String.t()) :: keyword()
  def credential_opts(provider_mod, api_key) when is_atom(provider_mod) and is_binary(api_key) do
    case provider_mod.id() do
      :openai ->
        [openai_api_key: api_key]

      :google ->
        [google_api_key: api_key]

      # If you add other providers later, extend this mapping.
      # Prefer explicit provider-specific keys over a generic `:api_key`.
      other ->
        raise ArgumentError,
              "Unsupported ReqLLM provider for credential options: #{inspect(other)} (#{inspect(provider_mod)})"
    end
  end
end
