defmodule Dialectic.LLM.Provider do
  @moduledoc """
  Behaviour and helpers for provider-specific LLM configuration (kept minimal).

  Goals:
  - Keep the streaming pipeline provider-agnostic.
  - Allow very simple providers that hardcode sensible defaults.
  - Keep configurability optional and incremental.

  Providers should implement:
    - `id/0` — provider identifier (e.g., `:openai`, `:google`)
    - `model/0` — model name (string)
    - `api_key/0` — API key value or `nil` if not configured
    - `provider_options/0` — keyword list for ReqLLM provider options (often `[]`)

  Optional callbacks (the worker uses sensible defaults if not implemented):
    - `connect_timeout/0` (defaults to 60_000 ms)
    - `receive_timeout/0` (defaults to 300_000 ms)
    - `tags/0` (defaults to `[]`)
    - `finch_name/0` (defaults to `Dialectic.Finch`)

  Note: For now we intentionally keep providers simple — it's fine to hardcode model
  names and options. Add environment-driven configuration only when you need it.

  Minimal example:

      defmodule Dialectic.LLM.Providers.Google do
        @behaviour Dialectic.LLM.Provider

        @impl true
        def id, do: :google

        @impl true
        def model, do: "gemini-2.0-flash-lite"

        @impl true
        def api_key, do: System.get_env("GEMINI_API_KEY")

        @impl true
        def provider_options, do: []

        # Optional overrides are not required; defaults will be used.
      end

  Worker usage:

      mod = Dialectic.LLM.Providers.Google
      spec = Dialectic.LLM.Provider.model_spec(mod)
      api_key = Dialectic.LLM.Provider.api_key!(mod)
      provider_opts = mod.provider_options()
      {connect_to, recv_to} = Dialectic.LLM.Provider.timeouts(mod)
      finch = Dialectic.LLM.Provider.finch_name(mod)
  """

  @typedoc "Provider identifier used by ReqLLM (e.g., :openai, :google, :anthropic, :deepseek)"
  @type provider_id :: atom()

  @typedoc "A module that implements this behaviour"
  @type provider_module :: module()

  @typedoc "The 2-tuple model spec {:provider_id, keyword()}"
  @type model_spec :: {provider_id(), keyword()}

  @doc "Provider identifier (e.g., :openai, :google)"
  @callback id() :: provider_id()

  @doc "Model name (string) for this provider"
  @callback model() :: String.t()

  @doc "API key for this provider, or nil if not configured"
  @callback api_key() :: String.t() | nil

  @doc "Provider-specific options for ReqLLM. Leave empty list if none."
  @callback provider_options() :: keyword()

  @default_connect_timeout 60_000
  @default_receive_timeout 300_000
  @default_finch Dialectic.Finch

  @doc """
  Build the 2-tuple model spec {:provider_id, [model: model]} used by `ReqLLM.stream_text/3`.
  """
  @spec model_spec(provider_module()) :: model_spec()
  def model_spec(mod) when is_atom(mod) do
    {mod.id(), [model: mod.model()]}
  end

  @doc """
  Returns `{connect_timeout_ms, receive_timeout_ms}` using provider overrides if present.

  Defaults to 60_000 and 300_000 respectively when the provider does not implement
  the optional callbacks.
  """
  @spec timeouts(provider_module()) :: {non_neg_integer(), non_neg_integer()}
  def timeouts(_mod), do: {@default_connect_timeout, @default_receive_timeout}

  @doc """
  Returns the Finch name for the provider, defaulting to `Dialectic.Finch`.
  """
  @spec finch_name(provider_module()) :: atom()
  def finch_name(_mod), do: @default_finch

  @doc """
  Returns any job tags the provider wishes to attach (or empty list).
  """
  @spec tags(provider_module()) :: [String.t()]
  def tags(_mod), do: []

  @doc """
  Returns the API key or raises a descriptive error if missing.
  Prefer `api_key/1` if you want to handle missing keys gracefully.
  """
  @spec api_key!(provider_module()) :: String.t()
  def api_key!(mod) do
    case mod.api_key() do
      nil -> raise "Missing API key for #{inspect(mod)} (#{inspect(mod.id())})"
      "" -> raise "Empty API key for #{inspect(mod)} (#{inspect(mod.id())})"
      key when is_binary(key) -> key
    end
  end

  @doc """
  Returns `{:ok, key}` when present or `{:error, reason}` when not.
  """
  @spec api_key(provider_module()) :: {:ok, String.t()} | {:error, :missing | :empty}
  def api_key(mod) do
    case mod.api_key() do
      nil -> {:error, :missing}
      "" -> {:error, :empty}
      key when is_binary(key) -> {:ok, key}
    end
  end

  @doc """
  Validates that the provider has a non-empty model and API key.
  Returns `:ok` or raises an error with a descriptive message.
  """
  @spec validate!(provider_module()) :: :ok
  def validate!(mod) do
    model = mod.model()

    cond do
      not is_binary(model) or model == "" ->
        raise "Invalid or empty model for #{inspect(mod)} (#{inspect(mod.id())})"

      true ->
        _ = api_key!(mod)
        :ok
    end
  end
end
