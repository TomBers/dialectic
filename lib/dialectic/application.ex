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
      # Start the Finch HTTP client for sending emails
      {Finch, name: Dialectic.Finch},
      DialecticWeb.Presence,
      {Dialectic.Responses.ModeServer, []},
      {DynamicSupervisor, name: GraphSupervisor},
      DialecticWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Dialectic.Supervisor]
    result = Supervisor.start_link(children, opts)

    # Warm up database connections after startup without blocking application start
    # Use spawn instead of TaskSupervisor to avoid race condition during startup
    spawn(fn -> warm_up_database() end)

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
end
