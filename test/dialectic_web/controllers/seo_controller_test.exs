defmodule DialecticWeb.SeoControllerTest do
  use DialecticWeb.ConnCase, async: false

  import Dialectic.AccountsFixtures
  import Dialectic.GraphFixtures

  alias Dialectic.Highlights

  describe "GET /robots.txt" do
    test "lets crawlers read graph canonical and noindex rules", %{conn: conn} do
      conn = get(conn, "/robots.txt")
      body = response(conn, 200)

      assert get_resp_header(conn, "content-type") |> List.first() =~ "text/plain"
      refute body =~ "Disallow: /g/*/graph"
      refute body =~ "Disallow: /g/*/linear"
      refute body =~ "Disallow: /g/*/outline"
      refute body =~ "Disallow: /*?node="
      assert body =~ "Disallow: /*?search="
      assert body =~ "Disallow: /*?token="
      assert body =~ "Sitemap: https://rationalgrid.ai/sitemap.xml"
    end
  end

  describe "graph page metadata" do
    test "reader route is indexable and canonical for public published graphs", %{conn: conn} do
      graph = insert_graph(%{title: "Reader SEO Graph"})
      conn = get(conn, "/g/#{graph.slug}")
      body = html_response(conn, 200)
      base_url = DialecticWeb.Endpoint.url()

      refute body =~ ~s(<meta name="robots" content="noindex, nofollow">)
      assert body =~ ~s(<link rel="canonical" href="#{base_url}/g/#{graph.slug}")
      assert body =~ ~s(<meta property="og:url" content="#{base_url}/g/#{graph.slug}")
      assert body =~ ~s(<meta name="twitter:url" content="#{base_url}/g/#{graph.slug}")
      assert body =~ ~s(<meta property="og:type" content="article")
      assert body =~ ~s(<script type="application/ld+json">)
      assert body =~ ~s("mainEntityOfPage")
      assert body =~ ~s("inLanguage":"en")
    end

    test "reader sends substantive node text before JavaScript runs", %{conn: conn} do
      graph =
        insert_graph(%{
          title: "Server Rendered Reader Graph",
          data: %{
            "nodes" => [
              %{
                "id" => "1",
                "content" =>
                  "# A searchable topic\n\nThis explanation is available in the initial HTML response.",
                "class" => "origin",
                "user" => nil,
                "parent" => nil,
                "noted_by" => [],
                "deleted" => false,
                "compound" => false
              }
            ],
            "edges" => []
          }
        })

      conn = get(conn, "/g/#{graph.slug}")
      body = html_response(conn, 200)

      assert body =~ ~s(data-role="server-markdown-fallback")
      assert body =~ "This explanation is available in the initial HTML response."

      assert body =~
               "Server Rendered Reader Graph: This explanation is available in the initial HTML response."
    end

    test "editor route is noindex and canonicalizes back to the reader", %{conn: conn} do
      graph = insert_graph(%{title: "Editor SEO Graph"})
      conn = get(conn, "/g/#{graph.slug}/graph")
      body = html_response(conn, 200)
      base_url = DialecticWeb.Endpoint.url()

      assert body =~ ~s(<meta name="robots" content="noindex, nofollow">)
      assert body =~ ~s(<link rel="canonical" href="#{base_url}/g/#{graph.slug}")
      assert body =~ ~s(<meta property="og:url" content="#{base_url}/g/#{graph.slug}")
      assert body =~ ~s(<meta name="twitter:url" content="#{base_url}/g/#{graph.slug}")
      refute body =~ ~s(<meta property="og:url" content="#{base_url}/g/#{graph.slug}/graph")
    end

    test "reader route stays noindex for unpublished graphs", %{conn: conn} do
      graph =
        insert_graph(%{title: "Unpublished SEO Graph", is_public: true, is_published: false})

      conn = get(conn, "/g/#{graph.slug}")
      body = html_response(conn, 200)

      assert body =~ ~s(<meta name="robots" content="noindex, nofollow">)
    end

    test "highlight share links publish quote-specific metadata", %{conn: conn} do
      graph = insert_graph(%{title: "Quote SEO Graph"})
      user = user_fixture()

      {:ok, highlight} =
        Highlights.create_highlight(%{
          mudg_id: graph.title,
          node_id: "1",
          text_source_type: "node",
          selection_start: 0,
          selection_end: 8,
          selected_text_snapshot: "A good quotation should point beyond itself.",
          created_by_user_id: user.id
        })

      conn = get(conn, "/g/#{graph.slug}?node=1&highlight=#{highlight.id}")
      body = html_response(conn, 200)
      base_url = DialecticWeb.Endpoint.url()

      assert body =~ ~s(<meta name="robots" content="noindex, nofollow">)

      assert body =~
               ~s(<link rel="canonical" href="#{base_url}/g/#{graph.slug}?node=1&amp;highlight=#{highlight.id}")

      assert body =~
               ~s(<meta property="og:image" content="#{base_url}/g/#{graph.slug}/highlights/#{highlight.id}/share-card.svg?v=)

      assert body =~ "A good quotation should point beyond itself."
      assert body =~ "Quote SEO Graph"
    end
  end
end
