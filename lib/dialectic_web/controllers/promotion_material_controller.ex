defmodule DialecticWeb.PromotionMaterialController do
  use DialecticWeb, :controller

  alias Dialectic.Content
  alias Dialectic.Content.PromotionMaterial

  def index(conn, _params) do
    json(conn, PromotionMaterial.list_graphs())
  end

  def show(conn, %{"graph_name" => graph_name}) do
    case Content.get_public_graph_by_slug_or_title(graph_name) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Grid not found"})

      graph ->
        json(conn, PromotionMaterial.build(graph))
    end
  end
end
