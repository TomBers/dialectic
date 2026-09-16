defmodule DialecticWeb.SitemapController do
  @moduledoc """
  Generates a dynamic sitemap.xml containing all public, published graphs.

  This helps search engines discover graph pages without needing to crawl
  link-by-link from the homepage.
  """
  use DialecticWeb, :controller

  alias Dialectic.Repo
  alias Dialectic.Accounts.Graph
  alias DialecticWeb.ComparisonController

  import Ecto.Query

  @page_size 50_000
  @minimum_ideas 21

  def index(conn, _params) do
    base_url = DialecticWeb.Endpoint.url()

    paths =
      [~p"/sitemap-pages.xml"] ++
        for(page <- 1..page_count(graph_query())//1, do: ~p"/sitemap-grids.xml?page=#{page}") ++
        for page <- 1..page_count(topic_query())//1, do: ~p"/sitemap-topics.xml?page=#{page}"

    entries = Enum.map(paths, &"<sitemap><loc>#{xml_escape(base_url <> &1)}</loc></sitemap>")
    send_xml(conn, xml_document("sitemapindex", entries))
  end

  def pages(conn, _params) do
    send_xml(conn, xml_document("urlset", static_entries(DialecticWeb.Endpoint.url())))
  end

  def grids(conn, params) do
    query = from g in graph_query(), order_by: [asc: g.slug]

    send_page(conn, params, query, fn graph ->
      lastmod =
        if graph.updated_at, do: graph.updated_at |> DateTime.to_date() |> Date.to_iso8601()

      url_entry(DialecticWeb.Endpoint.url() <> "/g/#{graph.slug}", lastmod, "weekly", "0.8")
    end)
  end

  def topics(conn, params) do
    query = from t in subquery(topic_query()), order_by: [asc: t.tag]

    send_page(conn, params, query, fn topic ->
      url_entry(
        DialecticWeb.Endpoint.url() <> ~p"/community?tag=#{topic.tag}",
        nil,
        "daily",
        "0.6"
      )
    end)
  end

  defp eligible_graph_query do
    from g in Graph,
      where: g.is_published == true and g.is_public == true,
      where: g.is_deleted == false or is_nil(g.is_deleted),
      where: not is_nil(g.slug) and g.slug != "",
      where:
        fragment(
          "(SELECT count(*) FROM jsonb_array_elements(CASE WHEN jsonb_typeof(?->'nodes') = 'array' THEN ?->'nodes' ELSE '[]'::jsonb END) AS node WHERE COALESCE(node->>'compound', 'false') != 'true')",
          g.data,
          g.data
        ) >= ^@minimum_ideas
  end

  defp graph_query do
    from g in eligible_graph_query(),
      select: %{slug: g.slug, updated_at: g.updated_at}
  end

  defp topic_query do
    tags = from g in eligible_graph_query(), select: %{tag: fragment("unnest(?)", g.tags)}

    from t in subquery(tags),
      where: fragment("btrim(?) != ''", t.tag),
      group_by: fragment("lower(btrim(?))", t.tag),
      select: %{tag: fragment("lower(btrim(?))", t.tag)}
  end

  defp page_count(query) do
    count = Repo.aggregate(from(entry in subquery(query)), :count)
    div(count + @page_size - 1, @page_size)
  end

  defp send_page(conn, params, query, entry_fun) do
    with value when is_binary(value) <- Map.get(params, "page", "1"),
         {page, ""} <- Integer.parse(value),
         true <- page > 0 and page <= max(1, page_count(query)) do
      entries =
        query
        |> limit(^@page_size)
        |> offset(^((page - 1) * @page_size))
        |> Repo.all()
        |> Enum.map(entry_fun)

      send_xml(conn, xml_document("urlset", entries))
    else
      _ -> send_resp(conn, 404, "Sitemap page not found")
    end
  end

  defp send_xml(conn, xml) do
    conn
    |> put_resp_content_type("application/xml")
    |> put_resp_header("cache-control", "public, max-age=3600")
    |> send_resp(200, xml)
  end

  defp static_entries(base_url) do
    [
      # Static pages
      url_entry(base_url <> "/", nil, "daily", "1.0"),
      url_entry(base_url <> "/about", nil, "monthly", "0.6"),
      url_entry(base_url <> "/intro/how", nil, "monthly", "0.5"),
      url_entry(base_url <> "/intro/ai", nil, "monthly", "0.5"),
      url_entry(base_url <> "/compare", nil, "monthly", "0.6"),
      url_entry(base_url <> "/community", nil, "daily", "0.7"),
      url_entry(base_url <> "/community?category=curated", nil, "daily", "0.7"),
      url_entry(
        base_url <> "/questions/does-ai-make-us-better-thinkers",
        "2026-09-07",
        "monthly",
        "0.8"
      ),
      url_entry(base_url <> "/inspiration", nil, "daily", "0.6"),
      url_entry(base_url <> "/gallery", nil, "weekly", "0.7")
    ] ++
      Enum.map(ComparisonController.slugs(), fn slug ->
        url_entry(base_url <> "/compare/#{slug}", nil, "monthly", "0.5")
      end)
  end

  defp xml_document(root, entries) do
    """
    <?xml version="1.0" encoding="UTF-8"?>
    <#{root} xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
    #{Enum.join(entries, "\n")}
    </#{root}>
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
      </url>
    """
    |> String.trim()
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
