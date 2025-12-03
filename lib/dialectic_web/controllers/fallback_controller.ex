defmodule DialecticWeb.FallbackController do
  @moduledoc """
  Translates controller return values to `Plug.Conn` responses.

  For example, `{:error, :not_found}` errors are translated
  to a 404 response.
  """
  use DialecticWeb, :controller

  # This clause handles errors returned by Ecto's insert/update/delete.
  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(json: DialecticWeb.ChangesetJSON)
    |> render(:error, changeset: changeset)
  end

  # This clause is an example of how to handle resources that cannot be found.
  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(html: DialecticWeb.ErrorHTML, json: DialecticWeb.ErrorJSON)
    |> render(:"404")
  end

  def call(conn, {:error, :unauthorized}) do
    conn
    |> put_status(:unauthorized)
    |> put_view(html: DialecticWeb.ErrorHTML, json: DialecticWeb.ErrorJSON)
    |> render(:"401")
  end

  def call(conn, {:error, :forbidden}) do
    conn
    |> put_status(:forbidden)
    |> put_view(html: DialecticWeb.ErrorHTML, json: DialecticWeb.ErrorJSON)
    |> render(:"403")
  end
end
