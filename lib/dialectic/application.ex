defmodule Dialectic.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    require Logger

    # Validate required API keys at startup (non-fatal)
    validate_api_keys()

    # Map GOOGLE_API_KEY to :google_api_key for ReqLLM
    if key = System.get_env("GOOGLE_API_KEY") do
      Application.put_env(:req_llm, :google_api_key, key)
    end

    children = [
      DialecticWeb.Telemetry,
      Dialectic.Repo,
      {DNSCluster, query: Application.get_env(:dialectic, :dns_cluster_query) || :ignore},
      {Oban, Application.fetch_env!(:dialectic, Oban)},
      {Phoenix.PubSub, name: Dialectic.PubSub},
      {Task.Supervisor, name: Dialectic.TaskSupervisor},
      # Start the Finch HTTP client with optimized connection pools
      # HTTP/2 pool for Gemini API reduces connection setup latency (TLS handshake, etc.)
      {Finch,
       name: Dialectic.Finch,
       pools: %{
         # HTTP/2 connection pool for Google Gemini API - keeps connections warm
         "https://generativelanguage.googleapis.com" => [
           protocols: [:http2],
           count: 2,
           conn_opts: [
             transport_opts: [timeout: 30_000]
           ]
         ],
         # HTTP/2 connection pool for OpenAI API (fallback provider)
         "https://api.openai.com" => [
           protocols: [:http2],
           count: 2,
           conn_opts: [
             transport_opts: [timeout: 30_000]
           ]
         ],
         # Default pool for other requests (emails, etc.)
         :default => [size: 10]
       }},
      DialecticWeb.Presence,
      {Dialectic.Responses.ModeServer, []},
      {DynamicSupervisor, name: GraphSupervisor},
      # ETS-based cache for Gravatar profile data (avoids hitting the
      # external API on every profile page mount)
      Dialectic.Accounts.GravatarCache,
      DialecticWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Dialectic.Supervisor]
    result = Supervisor.start_link(children, opts)

    # Warm up database connections after startup without blocking application start
    # Use spawn instead of TaskSupervisor to avoid race condition during startup
    spawn(fn -> warm_up_database() end)

    # Warm up HTTP/2 connections to LLM providers to reduce TTFT on first requests
    spawn(fn -> warm_up_llm_connections() end)

    result
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    DialecticWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp validate_api_keys do
    require Logger

    # Only validate in production to avoid breaking dev/test environments
    # In production (Fly.io), PHX_SERVER is always set
    if System.get_env("PHX_SERVER") do
      Logger.info("Running in production mode - validating API keys")

      # Check which LLM provider is configured
      provider = System.get_env("LLM_PROVIDER") || "openai"
      Logger.info("LLM Provider: #{provider}")

      case String.downcase(provider) do
        p when p in ["google", "gemini"] ->
          validate_key("GOOGLE_API_KEY", "Google/Gemini")

        "openai" ->
          validate_key("OPENAI_API_KEY", "OpenAI")

        _ ->
          validate_key("OPENAI_API_KEY", "OpenAI (default)")
      end
    else
      Logger.info("Running in development mode - skipping API key validation")
    end

    :ok
  end

  defp validate_key(env_var, provider_name) do
    require Logger

    case System.get_env(env_var) do
      nil ->
        Logger.error("""
        Missing required environment variable: #{env_var}
        #{provider_name} API key is required for production.
        Please set #{env_var} in your environment.
        Application will start but LLM features may not work.
        """)

        :ok

      "" ->
        Logger.error("""
        Empty environment variable: #{env_var}
        #{provider_name} API key cannot be empty in production.
        Application will start but LLM features may not work.
        """)

        :ok

      _key ->
        Logger.info("✓ #{provider_name} API key is configured")
        :ok
    end
  end

  defp warm_up_database do
    # Only warm up in production to prevent connection issues on Fly.io
    # In production (Fly.io), PHX_SERVER is always set
    if System.get_env("PHX_SERVER") do
      require Logger

      try do
        # Give the repo a moment to fully initialize
        Process.sleep(100)

        case Ecto.Adapters.SQL.query(Dialectic.Repo, "SELECT 1", []) do
          {:ok, _} ->
            Logger.info("Database warmup completed successfully")
            :ok

          {:error, error} ->
            Logger.warning("Database warmup failed: #{inspect(error)}")
            :ok
        end
      rescue
        error ->
          Logger.warning("Database warmup error: #{inspect(error)}")
          :ok
      end
    end
  end

  defp warm_up_llm_connections do
    require Logger

    # Give Finch a moment to fully initialize
    Process.sleep(500)

    # Determine which provider to warm up based on config
    provider = System.get_env("LLM_PROVIDER") || "openai"

    case String.downcase(provider) do
      p when p in ["google", "gemini"] ->
        warm_up_gemini_connection()

      _ ->
        warm_up_openai_connection()
    end
  end

  defp warm_up_gemini_connection do
    require Logger

    api_key = System.get_env("GOOGLE_API_KEY")

    if api_key && api_key != "" do
      try do
        # Make a minimal request to establish HTTP/2 connection
        # Using the models list endpoint which is lightweight
        url = "https://generativelanguage.googleapis.com/v1beta/models?key=#{api_key}"

        case Finch.build(:get, url) |> Finch.request(Dialectic.Finch) do
          {:ok, %{status: status}} when status in 200..299 ->
            Logger.info("✓ Gemini HTTP/2 connection warmed up successfully")

          {:ok, %{status: status}} ->
            Logger.warning("Gemini warmup returned status #{status}")

          {:error, error} ->
            Logger.warning("Gemini connection warmup failed: #{inspect(error)}")
        end
      rescue
        error ->
          Logger.warning("Gemini warmup error: #{inspect(error)}")
      end
    else
      Logger.debug("Skipping Gemini warmup - no API key configured")
    end
  end

  defp warm_up_openai_connection do
    require Logger

    api_key = System.get_env("OPENAI_API_KEY")

    if api_key && api_key != "" do
      try do
        # Make a minimal request to establish HTTP/2 connection
        # Using the models list endpoint which is lightweight
        url = "https://api.openai.com/v1/models"

        headers = [
          {"Authorization", "Bearer #{api_key}"},
          {"Content-Type", "application/json"}
        ]

        case Finch.build(:get, url, headers) |> Finch.request(Dialectic.Finch) do
          {:ok, %{status: status}} when status in 200..299 ->
            Logger.info("✓ OpenAI HTTP/2 connection warmed up successfully")

          {:ok, %{status: status}} ->
            Logger.warning("OpenAI warmup returned status #{status}")

          {:error, error} ->
            Logger.warning("OpenAI connection warmup failed: #{inspect(error)}")
        end
      rescue
        error ->
          Logger.warning("OpenAI warmup error: #{inspect(error)}")
      end
    else
      Logger.debug("Skipping OpenAI warmup - no API key configured")
    end
  end
end
