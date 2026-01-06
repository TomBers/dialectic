defmodule DialecticWeb.HealthControllerTest do
  use DialecticWeb.ConnCase

  test "GET /health", %{conn: conn} do
    conn = get(conn, ~p"/health")
    assert json_response(conn, 200)["status"] == "ok"
  end

  test "GET /health/deep", %{conn: conn} do
    conn = get(conn, ~p"/health/deep")

    # We accept 200 or 503 depending on whether all services (like Oban) are running in test env
    assert conn.status in [200, 503]

    response = json_response(conn, conn.status)
    assert response["status"] in ["ok", "degraded"]
    assert %{"application" => _, "database" => _, "oban" => _} = response["checks"]
  end
end
