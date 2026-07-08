defmodule DialecticWeb.PromotionMaterialController do
  use DialecticWeb, :controller

  alias Dialectic.Content
  alias Dialectic.Content.PromotionMaterial

  def show(conn, %{"graph_name" => graph_name} = params) do
    case Content.get_public_graph_by_slug_or_title(graph_name) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Grid not found"})

      graph ->
        material =
          PromotionMaterial.build(graph,
            include: Map.get(params, "include"),
            platforms: Map.get(params, "platforms"),
            utm_campaign: Map.get(params, "utm_campaign", "promotion_api")
          )

        json(conn, material)
    end
  end
end
