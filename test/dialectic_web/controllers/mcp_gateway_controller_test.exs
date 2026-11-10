defmodule DialecticWeb.McpGatewayControllerTest do
  use DialecticWeb.ConnCase, async: false

  setup do
    previous = Application.fetch_env(:dialectic, :mcp_gateway_req_options)
    Application.put_env(:dialectic, :mcp_gateway_req_options, plug: {Req.Test, __MODULE__})

    on_exit(fn ->
      case previous do
        {:ok, options} -> Application.put_env(:dialectic, :mcp_gateway_req_options, options)
        :error -> Application.delete_env(:dialectic, :mcp_gateway_req_options)
      end
    end)
  end

  test "the existing Phoenix origin forwards MCP calls and scoped authentication challenges", %{
    conn: conn
  } do
    Req.Test.stub(__MODULE__, fn upstream ->
      assert upstream.request_path == "/mcp"
      assert get_req_header(upstream, "authorization") == ["Bearer test-token"]
      assert get_req_header(upstream, "cookie") == []
      assert get_req_header(upstream, "origin") == ["https://rationalgrid.ai"]

      upstream =
        Plug.Parsers.call(upstream, Plug.Parsers.init(parsers: [:json], json_decoder: Jason))

      assert upstream.body_params["method"] == "tools/call"

      upstream
      |> put_resp_header("www-authenticate", "Bearer scope=\"grids:create grids:read\"")
      |> put_resp_content_type("application/json")
      |> send_resp(401, Jason.encode!(%{jsonrpc: "2.0", id: 1, result: %{isError: true}}))
    end)

    response =
      conn
      |> put_req_header("authorization", "Bearer test-token")
      |> put_req_header("cookie", "private-session")
      |> put_req_header("origin", "https://rationalgrid.ai")
      |> post(~p"/mcp", %{jsonrpc: "2.0", id: 1, method: "tools/call"})

    assert json_response(response, 401)["result"]["isError"]

    assert get_resp_header(response, "www-authenticate") == [
             "Bearer scope=\"grids:create grids:read\""
           ]

    assert get_resp_header(response, "cache-control") == ["no-store"]
  end

  test "metadata and unsupported methods preserve gateway responses", %{conn: conn} do
    Req.Test.stub(__MODULE__, fn upstream ->
      if upstream.request_path == "/mcp" do
        upstream |> put_resp_header("allow", "POST") |> send_resp(405, "Method not allowed")
      else
        assert upstream.request_path == "/.well-known/oauth-protected-resource/mcp"
        Req.Test.json(upstream, %{resource: "https://rationalgrid.ai/mcp"})
      end
    end)

    assert conn |> get(~p"/.well-known/oauth-protected-resource/mcp") |> json_response(200) == %{
             "resource" => "https://rationalgrid.ai/mcp"
           }

    response = get(conn, ~p"/mcp")
    assert response(response, 405) == "Method not allowed"
    assert get_resp_header(response, "allow") == ["POST"]
  end

  test "gateway failure returns a safe temporary failure", %{conn: conn} do
    Req.Test.stub(__MODULE__, fn upstream -> Req.Test.transport_error(upstream, :econnrefused) end)

    assert conn |> get(~p"/.well-known/oauth-protected-resource/mcp") |> json_response(503) == %{
             "error" => "MCP service is temporarily unavailable"
           }
  end
end
