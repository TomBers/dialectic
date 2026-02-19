defmodule DialecticWeb.SitemapControllerTest do
  use DialecticWeb.ConnCase

  alias Dialectic.Repo
  alias Dialectic.Accounts.Graph
  alias Dialectic.DbActions.Graphs

  defp insert_graph(attrs) do
    defaults = %{
      data: %{
        "nodes" => [
          %{
            "id" => "1",
            "content" => "## Test",
            "class" => "origin",
            "user" => "",
            "parent" => nil,
            "noted_by" => [],
            "deleted" => false,
            "compound" => false
          }
        ],
        "edges" => []
      },
      is_public: true,
      is_published: true,
      is_locked: false,
      is_deleted: false,
      prompt_mode: "university"
    }

    merged = Map.merge(defaults, attrs)
    slug = merged[:slug] || Graphs.generate_unique_slug(merged.title)

    %Graph{}
    |> Graph.changeset(%{
      title: merged.title,
      user_id: nil,
      data: merged.data,
      is_public: merged.is_public,
      is_published: merged.is_published,
      is_locked: merged.is_locked,
      is_deleted: merged.is_deleted,
      slug: slug,
      prompt_mode: merged.prompt_mode
    })
    |> Repo.insert!()
  end

  describe "GET /sitemap.xml" do
    test "returns 200 with XML content type", %{conn: conn} do
      conn = get(conn, "/sitemap.xml")

      assert conn.status == 200
      assert get_resp_header(conn, "content-type") |> List.first() =~ "xml"
    end

    test "sets cache-control header", %{conn: conn} do
      conn = get(conn, "/sitemap.xml")

      assert get_resp_header(conn, "cache-control") |> List.first() =~ "public, max-age=3600"
    end

    test "returns valid sitemap XML structure", %{conn: conn} do
      conn = get(conn, "/sitemap.xml")

      body = conn.resp_body
      assert body =~ ~r/<\?xml version="1.0" encoding="UTF-8"\?>/
      assert body =~ ~r/<urlset xmlns="http:\/\/www.sitemaps.org\/schemas\/sitemap\/0.9">/
      assert body =~ "</urlset>"
    end

    test "includes static pages", %{conn: conn} do
      conn = get(conn, "/sitemap.xml")

      body = conn.resp_body
      assert body =~ "https://mudg.fly.dev/"
      assert body =~ "https://mudg.fly.dev/intro/how"
      assert body =~ "https://mudg.fly.dev/inspiration"
    end

    test "includes public published graphs with slugs", %{conn: conn} do
      graph =
        insert_graph(%{title: "Public Graph Test", is_public: true, is_published: true})

      conn = get(conn, "/sitemap.xml")

      body = conn.resp_body
      assert body =~ "/g/#{graph.slug}"
    end

    test "excludes private graphs", %{conn: conn} do
      graph =
        insert_graph(%{title: "Private Graph Test", is_public: false, is_published: true})

      conn = get(conn, "/sitemap.xml")

      body = conn.resp_body
      refute body =~ "/g/#{graph.slug}"
    end

    test "excludes unpublished graphs", %{conn: conn} do
      graph =
        insert_graph(%{title: "Unpublished Graph Test", is_public: true, is_published: false})

      conn = get(conn, "/sitemap.xml")

      body = conn.resp_body
      refute body =~ "/g/#{graph.slug}"
    end

    test "excludes graphs with empty slugs", %{conn: conn} do
      # Insert directly to bypass slug validation
      Repo.insert!(%Graph{
        title: "No Slug Graph Test",
        data: %{"nodes" => [], "edges" => []},
        is_public: true,
        is_published: true,
        is_locked: false,
        is_deleted: false,
        slug: "",
        prompt_mode: "university"
      })

      conn = get(conn, "/sitemap.xml")

      body = conn.resp_body
      refute body =~ "No Slug Graph Test"
    end

    test "excludes graphs with nil slugs", %{conn: conn} do
      Repo.insert!(%Graph{
        title: "Nil Slug Graph Test",
        data: %{"nodes" => [], "edges" => []},
        is_public: true,
        is_published: true,
        is_locked: false,
        is_deleted: false,
        slug: nil,
        prompt_mode: "university"
      })

      conn = get(conn, "/sitemap.xml")

      body = conn.resp_body
      refute body =~ "Nil Slug Graph Test"
    end

    test "includes lastmod date for graphs", %{conn: conn} do
      insert_graph(%{title: "Dated Graph Test", is_public: true, is_published: true})

      conn = get(conn, "/sitemap.xml")

      body = conn.resp_body
      assert body =~ ~r/<lastmod>\d{4}-\d{2}-\d{2}<\/lastmod>/
    end

    test "does not emit backslash characters in output", %{conn: conn} do
      insert_graph(%{title: "Backslash Check Test", is_public: true, is_published: true})

      conn = get(conn, "/sitemap.xml")

      body = conn.resp_body
      refute body =~ "\\"
    end
  end
end
