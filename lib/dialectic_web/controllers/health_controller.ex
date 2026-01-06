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
  Deep health check that verifies database connectivity and critical services.
  Returns 200 OK if all systems are healthy, 503 Service Unavailable otherwise.
  """
  def deep(conn, _params) do
    checks = %{
      database: check_database(),
      oban: check_oban(),
      application: check_application()
    }

    all_healthy? = Enum.all?(checks, fn {_name, status} -> status == "ok" end)

    status_code = if all_healthy?, do: 200, else: 503

    conn
    |> put_status(status_code)
    |> json(%{
      status: if(all_healthy?, do: "ok", else: "degraded"),
      checks: checks,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    })
  end

  # Private helper functions

  defp check_database do
    try do
      case Ecto.Adapters.SQL.query(Dialectic.Repo, "SELECT 1", []) do
        {:ok, _} -> "ok"
        {:error, _} -> "error"
      end
    rescue
      _ -> "error"
    end
  end

  defp check_oban do
    try do
      # Check if Oban is running by checking for the Oban process
      case Process.whereis(Oban) do
        nil -> "error"
        _pid -> "ok"
      end
    rescue
      _ -> "error"
    end
  end

  defp check_application do
    # Basic check that the application is running
    if Application.started_applications() |> Enum.any?(fn {app, _, _} -> app == :dialectic end) do
      "ok"
    else
      "error"
    end
  end
end
