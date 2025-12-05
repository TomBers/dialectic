defmodule DialecticWeb.HighlightController do
  use DialecticWeb, :controller

  alias Dialectic.Highlights
  alias Dialectic.Highlights.Highlight

  action_fallback DialecticWeb.FallbackController

  def index(conn, %{"mudg_id" => mudg_id} = params) do
    current_user = conn.assigns[:current_user]
    graph = Dialectic.DbActions.Graphs.get_graph_by_title(mudg_id)
    token_param = params["token"]

    cond do
      is_nil(graph) ->
        {:error, :not_found}

      Dialectic.DbActions.Sharing.can_access?(current_user, graph) or
          (is_binary(token_param) and is_binary(graph.share_token) and
             Plug.Crypto.secure_compare(token_param, graph.share_token)) ->
        criteria = [mudg_id: mudg_id]

        criteria =
          if node_id = params["node_id"] do
            criteria ++ [node_id: node_id]
          else
            criteria
          end

        # Optional: filter by creator if "created_by_user_id" is present
        criteria =
          if user_id = params["created_by_user_id"] do
            criteria ++ [created_by_user_id: user_id]
          else
            criteria
          end

        highlights = Highlights.list_highlights(criteria)
        render(conn, :index, highlights: highlights)

      is_nil(current_user) ->
        {:error, :unauthorized}

      true ->
        {:error, :forbidden}
    end
  end

  def create(conn, %{"mudg_id" => mudg_id} = highlight_params) do
    current_user = conn.assigns[:current_user]
    graph = Dialectic.DbActions.Graphs.get_graph_by_title(mudg_id)

    if current_user && graph && Dialectic.DbActions.Sharing.can_access?(current_user, graph) do
      params = Map.put(highlight_params, "created_by_user_id", current_user.id)

      with {:ok, %Highlight{} = highlight} <- Highlights.create_highlight(params) do
        conn
        |> put_status(:created)
        |> render(:show, highlight: highlight)
      end
    else
      if is_nil(current_user), do: {:error, :unauthorized}, else: {:error, :forbidden}
    end
  end

  def update(conn, %{"id" => id} = highlight_params) do
    current_user = conn.assigns[:current_user]

    case Highlights.get_highlight(id) do
      nil ->
        {:error, :not_found}

      highlight ->
        graph = Dialectic.DbActions.Graphs.get_graph_by_title(highlight.mudg_id)

        cond do
          is_nil(current_user) ->
            {:error, :unauthorized}

          highlight.created_by_user_id != current_user.id ->
            {:error, :forbidden}

          !graph || !Dialectic.DbActions.Sharing.can_access?(current_user, graph) ->
            {:error, :forbidden}

          true ->
            # Filter to only allow note updates
            update_params = Map.take(highlight_params, ["note"])

            with {:ok, %Highlight{} = highlight} <-
                   Highlights.update_highlight(highlight, update_params) do
              render(conn, :show, highlight: highlight)
            end
        end
    end
  end

  def delete(conn, %{"id" => id}) do
    current_user = conn.assigns[:current_user]

    case Highlights.get_highlight(id) do
      nil ->
        {:error, :not_found}

      highlight ->
        graph = Dialectic.DbActions.Graphs.get_graph_by_title(highlight.mudg_id)

        cond do
          is_nil(current_user) ->
            {:error, :unauthorized}

          highlight.created_by_user_id != current_user.id ->
            {:error, :forbidden}

          !graph || !Dialectic.DbActions.Sharing.can_access?(current_user, graph) ->
            {:error, :forbidden}

          true ->
            with {:ok, %Highlight{}} <- Highlights.delete_highlight(highlight) do
              send_resp(conn, :no_content, "")
            end
        end
    end
  end
end
