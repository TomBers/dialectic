defmodule DialecticWeb.PublicGridController do
  use DialecticWeb, :controller

  alias Dialectic.Content
  alias Dialectic.Graph.Extractor
  alias Dialectic.Search

  plug :disable_cache

  def index(conn, params) do
    with {:ok, query} <- search_query(params["query"]),
         {:ok, limit} <- integer_param(params, "limit", 10, 1, 20) do
      grids =
        query
        |> Search.search_public(limit: limit)
        |> Enum.map(fn result ->
          result.graph
          |> metadata()
          |> Map.put(:matches, Enum.map(result.matches, &search_match/1))
        end)

      json(conn, %{grids: grids})
    else
      {:error, message} -> invalid_request(conn, message)
    end
  end

  def show(conn, %{"slug" => slug} = params) do
    with {:ok, limit} <- integer_param(params, "limit", 20, 1, 50),
         {:ok, offset} <- integer_param(params, "offset", 0, 0, 1_000_000),
         graph when not is_nil(graph) <- Content.get_public_graph_by_slug_or_title(slug) do
      {:ok, data} = Extractor.extract_for_image_generation(graph)
      nodes = Enum.slice(data.nodes, offset, limit)
      node_ids = MapSet.new(nodes, & &1.id)
      total_nodes = length(data.nodes)

      edges =
        Enum.filter(data.edges, fn edge ->
          MapSet.member?(node_ids, edge.from) or MapSet.member?(node_ids, edge.to)
        end)

      json(conn, %{
        grid: metadata(graph),
        nodes: nodes,
        edges: edges,
        total_nodes: total_nodes,
        next_offset: if(offset + limit < total_nodes, do: offset + limit, else: nil)
      })
    else
      nil -> conn |> put_status(:not_found) |> json(%{error: "Grid not found"})
      {:error, message} -> invalid_request(conn, message)
    end
  end

  defp metadata(graph) do
    slug = graph.slug || graph.title

    %{
      id: slug,
      title: graph.title,
      url: url(~p"/g/#{slug}"),
      tags: graph.tags || []
    }
  end

  defp search_match(node) do
    %{node_id: node["id"], snippet: node.search_preview}
  end

  defp search_query(query) when is_binary(query) do
    query = String.trim(query)

    if String.length(query) in 2..100 do
      {:ok, query}
    else
      {:error, "query must contain between 2 and 100 characters"}
    end
  end

  defp search_query(_query), do: {:error, "query must be a string"}

  defp integer_param(params, key, default, minimum, maximum) do
    case Map.get(params, key, Integer.to_string(default)) do
      value when is_binary(value) ->
        case Integer.parse(value) do
          {number, ""} when number >= minimum and number <= maximum -> {:ok, number}
          _ -> {:error, "#{key} must be an integer between #{minimum} and #{maximum}"}
        end

      _ ->
        {:error, "#{key} must be an integer between #{minimum} and #{maximum}"}
    end
  end

  defp invalid_request(conn, message) do
    conn |> put_status(:bad_request) |> json(%{error: message})
  end

  defp disable_cache(conn, _opts), do: put_resp_header(conn, "cache-control", "no-store")
end
