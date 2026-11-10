defmodule DialecticWeb.McpGridController do
  use DialecticWeb, :controller

  alias Dialectic.DbActions.Sharing
  alias Dialectic.Integrations.{ApiError, ChatGrids, GridActions, GridContent, OAuth}

  plug :authenticate when action != :capabilities

  def capabilities(conn, _params) do
    conn
    |> put_resp_header("cache-control", "no-store")
    |> json(Dialectic.Integrations.McpCapabilities.get())
  end

  def guided_exploration(conn, params) do
    conn.assigns.mcp_user
    |> ChatGrids.start_guided_exploration(params)
    |> action_response(conn)
  end

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
      _ ->
        error_response(conn, :bad_request, :invalid_arguments, "Invalid grid listing parameters")
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
        error_response(conn, status, reason, message)
    end
  end

  defp action_error(:not_found), do: {:not_found, "Grid not found"}

  defp action_error(:invalid_exploration),
    do:
      {:unprocessable_entity,
       "Provide a question of 1–4000 characters, an optional title of 1–140 characters, a supported response level and a UUID request_id"}

  defp action_error(:locked),
    do: {:locked, "Editing is disabled for this grid"}

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

  defp action_error(reason)
       when reason in [:rate_limited, :too_many_active_requests, :too_many_active_operations],
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
        error_response(
          conn,
          :conflict,
          :request_conflict,
          "This request_id was already used for different content"
        )

      {:error, :unavailable} ->
        error_response(
          conn,
          :gone,
          :unavailable,
          "The previously created grid is no longer available"
        )

      {:error, reason} when is_binary(reason) ->
        error_response(conn, :unprocessable_entity, :invalid_arguments, reason)

      {:error, _} ->
        error_response(conn, :unprocessable_entity, :invalid_arguments, "Grid could not be saved")
    end
  end

  def show(conn, %{"slug" => slug} = params) do
    with {:ok, limit} <- integer_param(params, "limit", 20, 1, 50),
         {:ok, offset, revision} <- pagination(params, slug),
         graph when not is_nil(graph) <- Sharing.get_accessible_graph(conn.assigns.mcp_user, slug),
         :ok <- revision_access(graph, revision, conn.assigns.mcp_user),
         {:ok, data, revision} <- GridContent.at_revision(graph, revision) do
      data = GridContent.serialize(data, graph.title, revision)
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
        snapshot_revision: revision,
        next_offset: if(offset + limit < total_nodes, do: offset + limit, else: nil),
        next_cursor:
          if(offset + limit < total_nodes,
            do:
              Phoenix.Token.sign(
                DialecticWeb.Endpoint,
                "mcp-grid-page",
                {slug, revision, offset + limit}
              ),
            else: nil
          )
      })
    else
      nil ->
        if conn.assigns.mcp_user do
          error_response(conn, :not_found, :not_found, "Grid not found")
        else
          error_response(conn, :unauthorized, :invalid_token, "invalid_token")
        end

      :error ->
        error_response(conn, :bad_request, :invalid_arguments, "Invalid pagination")

      {:error, :stale_snapshot} ->
        error_response(
          conn,
          :conflict,
          :stale_snapshot,
          "This revision is no longer available. Start a new read from the first page."
        )
    end
  end

  defp revision_access(_graph, nil, _user), do: :ok
  defp revision_access(%{data_revision: revision}, revision, _user), do: :ok
  defp revision_access(%{user_id: id}, _revision, %{id: id}), do: :ok
  defp revision_access(_graph, _revision, _user), do: {:error, :stale_snapshot}

  defp pagination(%{"cursor" => cursor}, slug)
       when is_binary(cursor) and byte_size(cursor) <= 2048 do
    case Phoenix.Token.verify(DialecticWeb.Endpoint, "mcp-grid-page", cursor, max_age: 604_800) do
      {:ok, {^slug, revision, offset}} when is_integer(revision) and is_integer(offset) ->
        {:ok, offset, revision}

      _ ->
        :error
    end
  end

  defp pagination(%{"cursor" => _}, _slug), do: :error

  defp pagination(params, _slug) do
    with {:ok, offset} <- integer_param(params, "offset", 0, 0, 1_000_000),
         {:ok, revision} <- revision_param(params) do
      {:ok, offset, revision}
    end
  end

  defp revision_param(%{"revision" => _} = params),
    do: integer_param(params, "revision", 0, 0, 9_007_199_254_740_991)

  defp revision_param(_), do: {:ok, nil}

  defp error_response(conn, status, reason, message) do
    data = ApiError.data(reason, conn.params["request_id"])

    conn =
      if data.retry_after_seconds,
        do: put_resp_header(conn, "retry-after", to_string(data.retry_after_seconds)),
        else: conn

    conn |> put_status(status) |> json(Map.put(data, :error, message))
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
        :guided_exploration -> "grids:create grids:read"
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

    authentication =
      if action_name(conn) == :show and get_req_header(conn, "authorization") == [],
        do: {:ok, nil},
        else: OAuth.authenticate(token, scope)

    case authentication do
      {:ok, user} ->
        conn
        |> assign(:mcp_user, user)
        |> assign(:current_user, user)
        |> DialecticWeb.Plugs.RateLimiter.call(type: :api, mcp_errors: true)

      {:error, reason} ->
        status = if reason == :insufficient_scope, do: :forbidden, else: :unauthorized
        conn = DialecticWeb.Plugs.RateLimiter.call(conn, type: :auth, mcp_errors: true)

        if conn.halted,
          do: conn,
          else: conn |> error_response(status, reason, reason) |> halt()
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
