defmodule DialecticWeb.SitemapController do
  @moduledoc """
  Generates a dynamic sitemap.xml containing all public, published graphs.

  This helps search engines discover graph pages without needing to crawl
  link-by-link from the homepage.
  """
  use DialecticWeb, :controller

  alias Dialectic.Repo
  alias Dialectic.Accounts.Graph

  import Ecto.Query

  def index(conn, _params) do
    base_url = DialecticWeb.Endpoint.url()

    graphs =
      from(g in Graph,
        where: g.is_published == true,
        where: g.is_public == true,
        where: not is_nil(g.slug),
        where: g.slug != "",
        select: %{slug: g.slug, updated_at: g.updated_at},
        order_by: [desc: g.updated_at]
      )
      |> Repo.all()

    xml = build_sitemap_xml(base_url, graphs)

    conn
    |> put_resp_content_type("application/xml")
    |> send_resp(200, xml)
  end

  defp build_sitemap_xml(base_url, graphs) do
    urls =
      [
        # Static pages
        url_entry(base_url <> "/", nil, "daily", "1.0"),
        url_entry(base_url <> "/intro/how", nil, "monthly", "0.5"),
        url_entry(base_url <> "/inspiration", nil, "daily", "0.6")
      ] ++
        Enum.map(graphs, fn graph ->
          lastmod =
            if graph.updated_at do
              DateTime.to_date(graph.updated_at) |> Date.to_iso8601()
            end

          url_entry(base_url <> "/g/#{graph.slug}", lastmod, "weekly", "0.8")
        end)

    """
    <?xml version="1.0" encoding="UTF-8"?>
    <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
    #{Enum.join(urls, "\n")}
    </urlset>
    """
    |> String.trim()
  end

  defp url_entry(loc, lastmod, changefreq, priority) do
    lastmod_tag =
      if lastmod do
        "    <lastmod>#{lastmod}</lastmod>\n"
      else
        ""
      end

    """
      <url>
        <loc>#{xml_escape(loc)}</loc>
    #{lastmod_tag}    <changefreq>#{changefreq}</changefreq>
        <priority>#{priority}</priority>
      </url>\
    """
  end

  defp xml_escape(str) do
    str
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&apos;")
  end
end
