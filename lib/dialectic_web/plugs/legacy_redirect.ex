defmodule DialecticWeb.Plugs.LegacyRedirect do
  @moduledoc """
  Controller that redirects legacy title-based graph URLs to new slug-based `/g/{slug}` URLs.

  Before the slug migration, graphs were accessible at `/:title` where title
  was the full URL-encoded graph title. After migration, all graphs live at
  `/g/{slug}`. Google still has the old URLs indexed and crawls them, producing
  795+ 404 errors in Search Console.

  This controller intercepts requests that don't match any known route and attempts
  to find a graph by title, issuing a 301 (permanent) redirect to the new
  slug-based URL if found. This tells search engines to transfer ranking
  signals to the canonical URL.

  ## Placement

  This should be added to the router **after** all normal routes, as a
  catch-all scope, so it only fires for paths that would otherwise 404.
  """

  use DialecticWeb, :controller

  alias Dialectic.DbActions.Graphs

  def redirect_graph(conn, %{"legacy_title" => legacy_title}) do
    decoded = URI.decode(legacy_title)

    case Graphs.get_graph_by_title(decoded) do
      %{slug: slug} when is_binary(slug) and slug != "" ->
        conn
        |> put_resp_header("cache-control", "public, max-age=86400")
        |> put_status(301)
        |> redirect(to: "/g/#{slug}")

      _ ->
        conn
        |> put_status(:not_found)
        |> put_view(html: DialecticWeb.ErrorHTML)
        |> render(:"404")
        |> halt()
    end
  end

  def redirect_linear(conn, %{"legacy_title" => legacy_title}) do
    decoded = URI.decode(legacy_title)

    case Graphs.get_graph_by_title(decoded) do
      %{slug: slug} when is_binary(slug) and slug != "" ->
        conn
        |> put_resp_header("cache-control", "public, max-age=86400")
        |> put_status(301)
        |> redirect(to: "/g/#{slug}/linear")

      _ ->
        conn
        |> put_status(:not_found)
        |> put_view(html: DialecticWeb.ErrorHTML)
        |> render(:"404")
        |> halt()
    end
  end
end
