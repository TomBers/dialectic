defmodule DialecticWeb.HighlightController do
  use DialecticWeb, :controller

  alias Dialectic.Highlights
  alias Dialectic.Highlights.Highlight

  action_fallback DialecticWeb.FallbackController

  def index(conn, %{"mudg_id" => mudg_id} = params) do
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
  end

  def create(conn, highlight_params) do
    current_user = conn.assigns[:current_user]

    if current_user do
      params = Map.put(highlight_params, "created_by_user_id", current_user.id)

      with {:ok, %Highlight{} = highlight} <- Highlights.create_highlight(params) do
        conn
        |> put_status(:created)
        |> render(:show, highlight: highlight)
      end
    else
      {:error, :unauthorized}
    end
  end

  def update(conn, %{"id" => id, "highlight" => highlight_params}) do
    highlight = Highlights.get_highlight!(id)
    current_user = conn.assigns[:current_user]

    cond do
      is_nil(current_user) ->
        {:error, :unauthorized}

      highlight.created_by_user_id != current_user.id ->
        {:error, :forbidden}

      true ->
        # For updates, we typically only allow updating the note
        # But we'll pass params through and let the changeset handle validation if needed,
        # usually update_highlight should restrict fields if strictness is required.
        # The schema changeset allows most fields, but logic dictates mostly note updates.
        with {:ok, %Highlight{} = highlight} <-
               Highlights.update_highlight(highlight, highlight_params) do
          render(conn, :show, highlight: highlight)
        end
    end
  end

  def delete(conn, %{"id" => id}) do
    highlight = Highlights.get_highlight!(id)
    current_user = conn.assigns[:current_user]

    cond do
      is_nil(current_user) ->
        {:error, :unauthorized}

      highlight.created_by_user_id != current_user.id ->
        {:error, :forbidden}

      true ->
        with {:ok, %Highlight{}} <- Highlights.delete_highlight(highlight) do
          send_resp(conn, :no_content, "")
        end
    end
  end
end
