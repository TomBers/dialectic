defmodule DialecticWeb.PromotionMaterialController do
  use DialecticWeb, :controller

  alias Dialectic.Content
  alias Dialectic.Content.PromotionMaterial

  def index(conn, _params) do
    with :ok <- authorize(conn) do
      json(conn, PromotionMaterial.list_graphs())
    else
      error -> auth_error(conn, error)
    end
  end

  def show(conn, %{"graph_name" => graph_name}) do
    with :ok <- authorize(conn),
         graph when not is_nil(graph) <- Content.get_public_graph_by_slug_or_title(graph_name) do
      json(conn, PromotionMaterial.build(graph))
    else
      {:error, _reason} = error ->
        auth_error(conn, error)

      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Grid not found"})
    end
  end

  defp authorize(conn) do
    case promotion_api_token() do
      nil ->
        {:error, :missing_token}

      expected_token ->
        conn
        |> bearer_token()
        |> token_equal?(expected_token)
        |> case do
          true -> :ok
          false -> {:error, :unauthorized}
        end
    end
  end

  defp auth_error(conn, {:error, :missing_token}) do
    conn
    |> put_status(:service_unavailable)
    |> json(%{error: "Promotion API token is not configured"})
  end

  defp auth_error(conn, {:error, :unauthorized}) do
    conn
    |> put_status(:unauthorized)
    |> json(%{error: "Unauthorized"})
  end

  defp promotion_api_token do
    token =
      Application.get_env(:dialectic, :promotion_api_token) ||
        System.get_env("PROMOTION_API_TOKEN")

    case token do
      token when is_binary(token) -> token |> String.trim() |> blank_to_nil()
      _ -> nil
    end
  end

  defp bearer_token(conn) do
    conn
    |> get_req_header("authorization")
    |> List.first()
    |> case do
      "Bearer " <> token -> token |> String.trim() |> blank_to_nil()
      _ -> nil
    end
  end

  defp token_equal?(left, right) when is_binary(left) and is_binary(right) do
    byte_size(left) == byte_size(right) and Plug.Crypto.secure_compare(left, right)
  end

  defp token_equal?(_left, _right), do: false

  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: value
end
