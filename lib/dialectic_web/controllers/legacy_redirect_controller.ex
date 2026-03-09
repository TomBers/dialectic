defmodule DialecticWeb.LegacyRedirectController do
  @moduledoc """
  Controller that redirects legacy title-based graph URLs to new slug-based `/g/{slug}` URLs.

  Before the slug migration, graphs were accessible at `/:title` where title
  was the full URL-encoded graph title. After migration, all graphs live at
  `/g/{slug}`. Google still has the old URLs indexed and crawls them, producing
  795+ 404 errors in Search Console.

  This controller is routed via catch-all routes at the bottom of the router:

    - `GET /:legacy_title` — matches single-segment paths not claimed by earlier routes
    - `GET /:legacy_title/linear` — matches legacy linear view URLs

  When a graph is found by title, a **301 permanent redirect** is issued to the
  corresponding `/g/{slug}` URL. Any query string on the original request
  (e.g. `?token=...`, `?node=...`, `?highlight=...`) is preserved on the
  redirect target so that legacy share links and deep-link params keep working.

  When no graph matches, a 404 is returned.

  ## Placement

  The catch-all routes must be defined **after** all other routes in the router
  so they only match paths that would otherwise 404.
  """

  use DialecticWeb, :controller

  alias Dialectic.DbActions.Graphs

  def redirect_graph(conn, %{"legacy_title" => legacy_title}) do
    decoded = URI.decode(legacy_title)

    case Graphs.get_graph_by_title(decoded) do
      %{slug: slug} when is_binary(slug) and slug != "" ->
        destination = build_destination("/g/#{slug}", conn.query_string)

        conn
        |> put_resp_header("cache-control", "public, max-age=86400")
        |> put_status(301)
        |> redirect(to: destination)

      _ ->
        conn
        |> put_status(:not_found)
        |> put_layout(false)
        |> put_view(html: DialecticWeb.ErrorHTML)
        |> render(:"404")
        |> halt()
    end
  end

  def redirect_linear(conn, %{"legacy_title" => legacy_title}) do
    decoded = URI.decode(legacy_title)

    case Graphs.get_graph_by_title(decoded) do
      %{slug: slug} when is_binary(slug) and slug != "" ->
        destination = build_destination("/g/#{slug}/linear", conn.query_string)

        conn
        |> put_resp_header("cache-control", "public, max-age=86400")
        |> put_status(301)
        |> redirect(to: destination)

      _ ->
        conn
        |> put_status(:not_found)
        |> put_layout(false)
        |> put_view(html: DialecticWeb.ErrorHTML)
        |> render(:"404")
        |> halt()
    end
  end

  defp build_destination(path, query_string) when query_string in [nil, ""], do: path
  defp build_destination(path, query_string), do: "#{path}?#{query_string}"
end
