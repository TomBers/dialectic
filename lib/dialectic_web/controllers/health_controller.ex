defmodule DialecticWeb.HealthController do
  use DialecticWeb, :controller

  @moduledoc """
  Health check endpoint for monitoring and load balancers.
  """

  @doc """
  Basic health check that verifies the application is running.
  Returns 200 OK with status information.
  """
  def check(conn, _params) do
    json(conn, %{
      status: "ok",
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    })
  end

  @doc """
  Deep health check that verifies database connectivity.
  Returns 200 OK if healthy, 503 Service Unavailable otherwise.
  """
  def deep(conn, _params) do
    db_status = check_database()
    is_healthy = db_status == "ok"

    conn
    |> put_status(if is_healthy, do: 200, else: 503)
    |> json(%{
      status: if(is_healthy, do: "ok", else: "error"),
      database: db_status,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    })
  end

  # Private helper functions

  defp check_database do
    case Ecto.Adapters.SQL.query(Dialectic.Repo, "SELECT 1", [], timeout: 1000) do
      {:ok, _} -> "ok"
      _ -> "error"
    end
  rescue
    _ -> "error"
  end
end
