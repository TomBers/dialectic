defmodule DialecticWeb.ThinkingMethodController do
  use DialecticWeb, :controller

  def show(conn, %{"method" => method}) do
    case Dialectic.Integrations.Thinking.get(method) do
      {:ok, result} -> json(conn, result)
      {:error, :not_found} -> conn |> put_status(:not_found) |> json(%{error: "Method not found"})
    end
  end
end
