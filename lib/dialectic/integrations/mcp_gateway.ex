defmodule Dialectic.Integrations.McpGateway do
  use GenServer
  require Logger

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  def ready? do
    case Req.get("http://127.0.0.1:4001/health",
           retry: false,
           receive_timeout: 500,
           connect_options: [timeout: 500]
         ) do
      {:ok, %{status: 200}} -> true
      _ -> false
    end
  end

  @impl true
  def init(opts) do
    Process.flag(:trap_exit, true)
    node = System.find_executable("node") || raise "Node.js is required for the MCP gateway"
    script = Keyword.get(opts, :script, "/app/mcp/dist/index.js")

    port =
      Port.open({:spawn_executable, node}, [
        :binary,
        :exit_status,
        :stderr_to_stdout,
        args: [script],
        env: [
          {~c"MCP_SUPERVISED", ~c"1"},
          {~c"NODE_ENV", ~c"production"},
          {~c"MCP_HOST", ~c"127.0.0.1"},
          {~c"MCP_PORT", ~c"4001"},
          {~c"PHOENIX_BASE_URL",
           String.to_charlist("http://127.0.0.1:" <> (System.get_env("PORT") || "4000"))},
          {~c"MCP_PUBLIC_URL", String.to_charlist(Dialectic.Integrations.OAuth.resource())},
          {~c"OAUTH_ISSUER_URL", String.to_charlist(DialecticWeb.Endpoint.url())}
        ]
      ])

    {:ok, %{port: port}}
  end

  @impl true
  def handle_info({port, {:data, data}}, %{port: port} = state) do
    Logger.info("[MCP] " <> String.trim(data))
    {:noreply, state}
  end

  def handle_info({port, {:exit_status, status}}, %{port: port} = state),
    do: {:stop, {:gateway_exit, status}, state}

  def handle_info({:EXIT, port, reason}, %{port: port} = state), do: {:stop, reason, state}

  @impl true
  def terminate(_reason, %{port: port}) do
    if Port.info(port), do: Port.close(port)
    :ok
  end
end
