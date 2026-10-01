defmodule DialecticWeb.McpGridController do
  use DialecticWeb, :controller

  alias Dialectic.Graph.Extractor
  alias Dialectic.Integrations.{ChatGrids, OAuth}

  plug :authenticate

  def create(conn, params) do
    case ChatGrids.create(conn.assigns.mcp_user, params) do
      {:ok, graph} ->
        json(conn, %{grid: metadata(graph), node_count: length(graph.data["nodes"])})

      {:error, :request_conflict} ->
        conn
        |> put_status(:conflict)
        |> json(%{error: "This request_id was already used for different content"})

      {:error, :unavailable} ->
        conn
        |> put_status(:gone)
        |> json(%{error: "The previously created grid is no longer available"})

      {:error, reason} when is_binary(reason) ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: reason})

      {:error, _} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "Grid could not be saved"})
    end
  end

  def show(conn, %{"slug" => slug} = params) do
    with {:ok, limit} <- integer_param(params, "limit", 20, 1, 50),
         {:ok, offset} <- integer_param(params, "offset", 0, 0, 1_000_000),
         graph when not is_nil(graph) <- ChatGrids.get(conn.assigns.mcp_user, slug) do
      {:ok, data} = Extractor.extract_for_image_generation(graph)
      nodes = Enum.slice(data.nodes, offset, limit)
      node_ids = MapSet.new(nodes, & &1.id)

      edges =
        Enum.filter(
          data.edges,
          &(MapSet.member?(node_ids, &1.from) or MapSet.member?(node_ids, &1.to))
        )

      total_nodes = length(data.nodes)

      json(conn, %{
        grid: metadata(graph),
        nodes: nodes,
        edges: edges,
        total_nodes: total_nodes,
        next_offset: if(offset + limit < total_nodes, do: offset + limit, else: nil)
      })
    else
      nil -> conn |> put_status(:not_found) |> json(%{error: "Grid not found"})
      :error -> conn |> put_status(:bad_request) |> json(%{error: "Invalid pagination"})
    end
  end

  defp integer_param(params, key, default, minimum, maximum) do
    case Map.get(params, key, Integer.to_string(default)) do
      value when is_binary(value) ->
        case Integer.parse(value) do
          {number, ""} when number >= minimum and number <= maximum -> {:ok, number}
          _ -> :error
        end

      _ ->
        :error
    end
  end

  defp authenticate(conn, _opts) do
    scope = if action_name(conn) == :create, do: "grids:create", else: "grids:read"

    token =
      case get_req_header(conn, "authorization") do
        ["Bearer " <> token] -> token
        _ -> nil
      end

    conn = put_resp_header(conn, "cache-control", "no-store")

    case OAuth.authenticate(token, scope) do
      {:ok, user} ->
        assign(conn, :mcp_user, user)

      {:error, reason} ->
        status = if reason == :insufficient_scope, do: :forbidden, else: :unauthorized
        conn |> put_status(status) |> json(%{error: reason}) |> halt()
    end
  end

  defp metadata(graph),
    do: %{
      id: graph.slug,
      title: graph.title,
      url: url(~p"/g/#{graph.slug}"),
      tags: graph.tags || [],
      visibility: if(graph.is_public, do: "public", else: "private")
    }
end
