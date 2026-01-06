defmodule Dialectic.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # Validate required API keys at startup
    validate_api_keys!()

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
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    DialecticWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp validate_api_keys! do
    # Only validate in production to avoid breaking dev/test environments
    if Application.get_env(:dialectic, :env) == :prod do
      # Check which LLM provider is configured
      provider = System.get_env("LLM_PROVIDER") || "openai"

      case String.downcase(provider) do
        p when p in ["google", "gemini"] ->
          validate_key!("GOOGLE_API_KEY", "Google/Gemini")

        "openai" ->
          validate_key!("OPENAI_API_KEY", "OpenAI")

        _ ->
          validate_key!("OPENAI_API_KEY", "OpenAI (default)")
      end
    end

    :ok
  end

  defp validate_key!(env_var, provider_name) do
    case System.get_env(env_var) do
      nil ->
        raise """
        Missing required environment variable: #{env_var}
        #{provider_name} API key is required for production.
        Please set #{env_var} in your environment.
        """

      "" ->
        raise """
        Empty environment variable: #{env_var}
        #{provider_name} API key cannot be empty in production.
        """

      _key ->
        :ok
    end
  end
end
