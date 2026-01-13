defmodule DialecticWeb.HealthControllerTest do
  use DialecticWeb.ConnCase

  test "GET /health", %{conn: conn} do
    conn = get(conn, ~p"/health")
    assert json_response(conn, 200)["status"] == "ok"
  end

  test "GET /health/deep", %{conn: conn} do
    conn = get(conn, ~p"/health/deep")

    # We accept 200 or 503 depending on whether database connectivity works
    assert conn.status in [200, 503]

    response = json_response(conn, conn.status)
    assert response["status"] in ["ok", "error"]
    assert response["database"] in ["ok", "error"]
    assert response["timestamp"]
  end
end
