defmodule DialecticWeb.McpGatewayController do
  use DialecticWeb, :controller

  @request_headers ~w(accept authorization origin mcp-protocol-version mcp-session-id last-event-id)
  @response_headers ~w(content-type www-authenticate allow mcp-session-id retry-after)
  @methods %{
    "GET" => :get,
    "POST" => :post,
    "PUT" => :put,
    "PATCH" => :patch,
    "DELETE" => :delete,
    "HEAD" => :head,
    "OPTIONS" => :options,
    "TRACE" => :trace,
    "CONNECT" => :connect
  }

  def forward(conn, _params) do
    headers = Enum.filter(conn.req_headers, fn {name, _} -> name in @request_headers end)

    opts = [
      method: Map.get(@methods, conn.method, :options),
      url: "http://127.0.0.1:4001" <> conn.request_path,
      headers: headers,
      retry: false,
      redirect: false,
      decode_body: false,
      receive_timeout: 15_000,
      connect_options: [timeout: 1000]
    ]

    opts = if conn.method == "POST", do: Keyword.put(opts, :json, conn.body_params), else: opts
    opts = Keyword.merge(opts, Application.get_env(:dialectic, :mcp_gateway_req_options, []))
    conn = put_resp_header(conn, "cache-control", "no-store")

    case Req.request(opts) do
      {:ok, response} ->
        conn =
          Enum.reduce(@response_headers, conn, fn name, conn ->
            case Req.Response.get_header(response, name) do
              [] -> conn
              values -> put_resp_header(conn, name, Enum.join(values, ", "))
            end
          end)

        send_resp(conn, response.status, response.body)

      {:error, _} ->
        conn
        |> put_status(:service_unavailable)
        |> json(%{error: "MCP service is temporarily unavailable"})
    end
  end
end
