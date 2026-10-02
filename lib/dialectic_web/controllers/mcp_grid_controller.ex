defmodule DialecticWeb.McpGridController do
  use DialecticWeb, :controller

  alias Dialectic.Graph.Extractor
  alias Dialectic.Integrations.{ChatGrids, GridActions, OAuth}

  plug :authenticate

  def start_exploration(conn, params) do
    conn.assigns.mcp_user
    |> ChatGrids.start_exploration(params)
    |> action_response(conn)
  end

  def operation(conn, %{"request_id" => request_id}) do
    conn.assigns.mcp_user
    |> GridActions.get_operation(request_id)
    |> action_response(conn)
  end

  def index(conn, params) do
    with {:ok, limit} <- integer_param(params, "limit", 20, 1, 50),
         query when is_binary(query) <- Map.get(params, "query", ""),
         true <- String.length(query) <= 100,
         cursor <- params["cursor"],
         true <- is_nil(cursor) or (is_binary(cursor) and byte_size(cursor) in 1..255) do
      result =
        ChatGrids.list_owned(conn.assigns.mcp_user, %{
          limit: limit,
          query: String.trim(query),
          cursor: cursor
        })

      json(conn, %{grids: Enum.map(result.grids, &metadata/1), next_cursor: result.next_cursor})
    else
      _ -> conn |> put_status(:bad_request) |> json(%{error: "Invalid grid listing parameters"})
    end
  end

  def add_idea(conn, %{"slug" => slug} = params) do
    conn.assigns.mcp_user
    |> GridActions.add_idea(slug, params)
    |> action_response(conn)
  end

  def apply_action(conn, %{"slug" => slug} = params) do
    conn.assigns.mcp_user
    |> GridActions.apply(slug, params)
    |> action_response(conn)
  end

  defp action_response(result, conn) do
    case result do
      {:ok, %{graph: graph} = result} ->
        json(conn, result |> Map.delete(:graph) |> Map.put(:grid, metadata(graph)))

      {:error, reason} ->
        {status, message} = action_error(reason)
        conn |> put_status(status) |> json(%{error: message})
    end
  end

  defp action_error(:not_found), do: {:not_found, "Grid not found"}

  defp action_error(:invalid_exploration),
    do:
      {:unprocessable_entity,
       "Provide a question of 1–4000 characters, an optional title of 1–140 characters, a supported response level and a UUID request_id"}

  defp action_error(:locked),
    do: {:locked, "Unlock this grid in RationalGrid before adding a node"}

  defp action_error(:request_conflict),
    do: {:conflict, "This request_id was already used for a different action"}

  defp action_error(:unavailable), do: {:gone, "The previously added node is no longer available"}

  defp action_error(:invalid_content),
    do: {:unprocessable_entity, "Provide nonblank idea content of at most 4000 characters"}

  defp action_error(:invalid_kind),
    do:
      {:unprocessable_entity,
       "Choose comment to save text only, or question to generate an AI answer"}

  defp action_error(:stale),
    do: {:conflict, "The live grid is behind its saved version; reopen it before retrying"}

  defp action_error(reason) when reason in [:rate_limited, :too_many_active_requests],
    do: {:too_many_requests, "Please wait for existing AI requests to finish before retrying"}

  defp action_error(_),
    do:
      {:unprocessable_entity,
       "Choose a supported action and an existing, nonempty idea node; provide a UUID request_id"}

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
    scope =
      case action_name(conn) do
        :create -> "grids:create"
        :start_exploration -> "grids:create"
        :index -> "grids:read"
        :operation -> "grids:read"
        :apply_action -> "grids:append"
        :add_idea -> "grids:append"
        :show -> "grids:read"
      end

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
