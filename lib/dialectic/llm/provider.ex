defmodule Dialectic.LLM.Provider do
  @moduledoc """
  Behaviour and minimal helpers for provider-specific LLM configuration.

  Implement this behaviour for each provider (e.g., OpenAI, Google/Gemini, Anthropic)
  so the core streaming code remains provider-agnostic. A provider module encapsulates:
    - provider identifier (e.g., `:openai`, `:google`)
    - model name (string)
    - API key retrieval
    - provider-specific options for ReqLLM (`provider_options/0`)
    - optional timeouts and Finch name

  The core streaming pipeline can then depend on this behaviour to:
    - construct a `model_spec/1` tuple {:provider, model, []}
    - fetch the API key
    - derive provider-specific options without branching logic

  Example:

      defmodule Dialectic.LLM.Providers.Google do
        @behaviour Dialectic.LLM.Provider

        @impl true
        def id, do: :google

        @impl true
        def model, do: System.get_env("GOOGLE_MODEL") || "gemini-1.5-flash"

        @impl true
        def api_key, do: System.get_env("GOOGLE_API_KEY") || System.get_env("GEMINI_API_KEY")

        @impl true
        def provider_options do
          base = []

          base =
            if System.get_env("GOOGLE_GROUNDING_ENABLE") in ["1", "true", "TRUE"] do
              Keyword.put(base, :google_grounding, %{enable: true})
            else
              base
            end

          base =
            case System.get_env("GOOGLE_API_VERSION") do
              "v1beta" -> Keyword.put(base, :google_api_version, "v1beta")
              "v1" -> Keyword.put(base, :google_api_version, "v1")
              _ -> base
            end

          base
        end

        # Optional callbacks
        def tags, do: ["google", "gemini"]
      end

  The core worker could then call:

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

  @typedoc "The 3-tuple model spec {:provider_id, model_name, model_options}"
  @type model_spec :: {provider_id(), String.t(), keyword()}

  @doc "Provider identifier (e.g., :openai, :google)"
  @callback id() :: provider_id()

  @doc "Model name (string) for this provider"
  @callback model() :: String.t()

  @doc "API key for this provider, or nil if not configured"
  @callback api_key() :: String.t() | nil

  @doc "Provider-specific options for ReqLLM. Leave empty list if none."
  @callback provider_options() :: keyword()

  @doc "Optional: Per-provider connect timeout in milliseconds"
  @callback connect_timeout() :: non_neg_integer()

  @doc "Optional: Per-provider receive timeout in milliseconds"
  @callback receive_timeout() :: non_neg_integer()

  @doc "Optional: Job tags for metrics or queue tagging"
  @callback tags() :: [String.t()]

  @doc "Optional: Finch instance name to use for this provider"
  @callback finch_name() :: atom()

  @optional_callbacks connect_timeout: 0,
                      receive_timeout: 0,
                      tags: 0,
                      finch_name: 0

  @default_connect_timeout 60_000
  @default_receive_timeout 300_000
  @default_finch Dialectic.Finch

  @doc """
  Build the 3-tuple model spec {:provider_id, model, []} used by `ReqLLM.stream_text/3`.

  The third element is reserved for model-specific options, but most providers
  can leave this empty list and rely on `provider_options/0` for their settings.
  """
  @spec model_spec(provider_module()) :: model_spec()
  def model_spec(mod) when is_atom(mod) do
    {mod.id(), mod.model(), []}
  end

  @doc """
  Returns `{connect_timeout_ms, receive_timeout_ms}` using provider overrides if present.

  Defaults to 60_000 and 300_000 respectively when the provider does not implement
  the optional callbacks.
  """
  @spec timeouts(provider_module()) :: {non_neg_integer(), non_neg_integer()}
  def timeouts(mod) do
    connect =
      if function_exported?(mod, :connect_timeout, 0),
        do: mod.connect_timeout(),
        else: @default_connect_timeout

    receive_ =
      if function_exported?(mod, :receive_timeout, 0),
        do: mod.receive_timeout(),
        else: @default_receive_timeout

    {connect, receive_}
  end

  @doc """
  Returns the Finch name for the provider, defaulting to `Dialectic.Finch`.
  """
  @spec finch_name(provider_module()) :: atom()
  def finch_name(mod) do
    if function_exported?(mod, :finch_name, 0),
      do: mod.finch_name(),
      else: @default_finch
  end

  @doc """
  Returns any job tags the provider wishes to attach (or empty list).
  """
  @spec tags(provider_module()) :: [String.t()]
  def tags(mod) do
    if function_exported?(mod, :tags, 0), do: mod.tags(), else: []
  end

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
