defmodule Dialectic.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      DialecticWeb.Telemetry,
      Dialectic.Repo,
      {DNSCluster, query: Application.get_env(:dialectic, :dns_cluster_query) || :ignore},
      {Oban, Application.fetch_env!(:dialectic, Oban)},
      {Phoenix.PubSub, name: Dialectic.PubSub},
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
end
