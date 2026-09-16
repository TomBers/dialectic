defmodule DialecticWeb.SitemapControllerTest do
  use DialecticWeb.ConnCase

  alias Dialectic.Repo
  alias Dialectic.Accounts.Graph

  import Dialectic.GraphFixtures

  describe "sitemap endpoints" do
    test "returns 200 with XML content type", %{conn: conn} do
      for path <- [
            "/sitemap.xml",
            "/sitemap-pages.xml",
            "/sitemap-grids.xml",
            "/sitemap-topics.xml"
          ] do
        conn = get(conn, path)
        assert conn.status == 200
        assert get_resp_header(conn, "content-type") |> List.first() =~ "xml"
      end
    end

    test "sets cache-control header", %{conn: conn} do
      for path <- [
            "/sitemap.xml",
            "/sitemap-pages.xml",
            "/sitemap-grids.xml",
            "/sitemap-topics.xml"
          ] do
        conn = get(conn, path)
        assert get_resp_header(conn, "cache-control") |> List.first() =~ "public, max-age=3600"
      end
    end

    test "returns a sitemap index linking to the public content sitemaps", %{conn: conn} do
      conn = get(conn, "/sitemap.xml")

      body = conn.resp_body
      assert body =~ ~r/<\?xml version="1.0" encoding="UTF-8"\?>/
      assert body =~ ~s(<sitemapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">)
      assert body =~ "</sitemapindex>"
      assert body =~ "<loc>#{DialecticWeb.Endpoint.url()}/sitemap-pages.xml</loc>"
      refute body =~ "/sitemap-grids.xml"
      refute body =~ "/sitemap-topics.xml"
    end

    test "every indexed sitemap is reachable and contains only URL entries", %{conn: conn} do
      developed_graph(%{title: "Indexed sitemap graph"})
      |> Ecto.Changeset.change(tags: ["Sociology"])
      |> Repo.update!()

      base_url = DialecticWeb.Endpoint.url()
      index = conn |> get("/sitemap.xml") |> response(200)

      assert locations(index) == [
               base_url <> "/sitemap-pages.xml",
               base_url <> "/sitemap-grids.xml?page=1",
               base_url <> "/sitemap-topics.xml?page=1"
             ]

      for url <- locations(index) do
        body = conn |> get(String.replace_prefix(url, base_url, "")) |> response(200)
        assert body =~ ~s(<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">)
        assert body =~ "</urlset>"
        assert length(locations(body)) in 1..50_000
        refute body =~ "<sitemap>"
      end
    end

    test "graph pagination includes every grid once beyond the 50,000-URL boundary", %{conn: conn} do
      now = ~U[2026-09-16 12:00:00Z]

      slugs =
        for index <- 1..50_000,
            do: "sitemap-grid-" <> String.pad_leading(to_string(index), 5, "0")

      slugs
      |> Enum.map(fn slug ->
        %{
          title: slug,
          slug: slug,
          data: grid_data(21),
          is_public: true,
          is_published: true,
          is_deleted: false,
          inserted_at: now,
          updated_at: now
        }
      end)
      |> Enum.chunk_every(1_000)
      |> Enum.each(&Repo.insert_all(Graph, &1))

      index = conn |> get("/sitemap.xml") |> response(200)
      assert index =~ "/sitemap-grids.xml?page=1"
      refute index =~ "/sitemap-grids.xml?page=2"

      extra = developed_graph(%{title: "One extra grid", slug: "sitemap-grid-50001"})
      index = conn |> get("/sitemap.xml") |> response(200)
      assert index =~ "/sitemap-grids.xml?page=2"
      refute index =~ "/sitemap-grids.xml?page=3"

      first = conn |> get("/sitemap-grids.xml?page=1") |> response(200) |> locations()
      second = conn |> get("/sitemap-grids.xml?page=2") |> response(200) |> locations()
      base_url = DialecticWeb.Endpoint.url()

      assert first == Enum.map(slugs, &(base_url <> "/g/" <> &1))
      assert second == [base_url <> "/g/" <> extra.slug]
      assert length(first) == 50_000
      assert length(second) == 1
    end

    test "topic pagination has its own URL budget and preserves every normalized topic", %{
      conn: conn
    } do
      tags = for index <- 1..50_000, do: "Topic " <> String.pad_leading(to_string(index), 5, "0")

      graph =
        developed_graph(%{title: "Many sitemap topics"})
        |> Ecto.Changeset.change(tags: tags ++ [" TOPIC 00001 ", "", " "])
        |> Repo.update!()

      index = conn |> get("/sitemap.xml") |> response(200)
      refute index =~ "/sitemap-topics.xml?page=2"

      graph |> Ecto.Changeset.change(tags: graph.tags ++ ["Topic 50001"]) |> Repo.update!()
      index = conn |> get("/sitemap.xml") |> response(200)
      assert index =~ "/sitemap-pages.xml"
      assert index =~ "/sitemap-grids.xml?page=1"
      assert index =~ "/sitemap-topics.xml?page=2"
      refute index =~ "/sitemap-topics.xml?page=3"

      first = conn |> get("/sitemap-topics.xml?page=1") |> response(200) |> locations()
      second = conn |> get("/sitemap-topics.xml?page=2") |> response(200) |> locations()
      base_url = DialecticWeb.Endpoint.url()

      assert first == Enum.map(tags, &(base_url <> ~p"/community?tag=#{String.downcase(&1)}"))
      assert second == [base_url <> "/community?tag=topic+50001"]
      assert length(first) == 50_000
      assert length(second) == 1
    end

    test "rejects invalid and out-of-range sitemap pages", %{conn: conn} do
      for path <- ["/sitemap-grids.xml", "/sitemap-topics.xml"],
          query <- [
            "page=0",
            "page=-1",
            "page=2",
            "page=abc",
            "page=1abc",
            "page=999999999999999999999",
            "page[]=1"
          ] do
        assert conn |> get(path <> "?" <> query) |> response(404) == "Sitemap page not found"
      end
    end

    test "includes static pages", %{conn: conn} do
      conn = get(conn, "/sitemap-pages.xml")

      base_url = DialecticWeb.Endpoint.url()
      body = conn.resp_body
      assert body =~ "#{base_url}/"
      assert body =~ "#{base_url}/intro/how"
      assert body =~ "#{base_url}/intro/ai"
      assert body =~ "#{base_url}/community"
      assert body =~ "<loc>#{base_url}/community?category=curated</loc>"
      assert body =~ "#{base_url}/inspiration"
    end

    test "includes every comparison page", %{conn: conn} do
      conn = get(conn, "/sitemap-pages.xml")

      body = conn.resp_body
      base_url = DialecticWeb.Endpoint.url()

      assert body =~ "<loc>#{base_url}/compare</loc>"

      for slug <- DialecticWeb.ComparisonController.slugs() do
        assert body =~ "#{DialecticWeb.Endpoint.url()}/compare/#{slug}"
      end
    end

    test "includes public published graphs with slugs", %{conn: conn} do
      graph =
        developed_graph(%{title: "Public Graph Test", is_public: true, is_published: true})

      conn = get(conn, "/sitemap-grids.xml")

      body = conn.resp_body
      assert body =~ "/g/#{graph.slug}"
    end

    test "only grids with at least 21 ideas qualify, excluding compound groups", %{conn: conn} do
      included =
        for count <- [21, 22],
            do:
              developed_graph(%{
                title: "Developed grid with #{count} ideas",
                data: grid_data(count)
              })

      excluded =
        for count <- [0, 1, 4, 5, 20] do
          data = grid_data(count)
          groups = for index <- 1..25, do: %{"id" => "group-#{index}", "compound" => true}
          data = Map.update!(data, "nodes", &(&1 ++ groups))
          developed_graph(%{title: "Small grid with #{count} ideas", data: data})
        end

      body = conn |> get("/sitemap-grids.xml") |> response(200)
      expected = Enum.map(included, &(DialecticWeb.Endpoint.url() <> "/g/" <> &1.slug))
      assert MapSet.new(locations(body)) == MapSet.new(expected)

      browsable_slugs =
        Dialectic.DbActions.Graphs.browse_public_graphs().entries
        |> MapSet.new(& &1.graph.slug)

      assert MapSet.subset?(MapSet.new(excluded, & &1.slug), browsable_slugs)
    end

    test "missing or invalid node collections do not qualify", %{conn: conn} do
      for {label, data} <- [
            {"missing", %{}},
            {"null", %{"nodes" => nil}},
            {"map", %{"nodes" => %{}}},
            {"text", %{"nodes" => "not a collection"}}
          ] do
        developed_graph(%{title: "Grid with #{label} nodes", data: data})
      end

      assert conn |> get("/sitemap-grids.xml") |> response(200) |> locations() == []
      refute conn |> get("/sitemap.xml") |> response(200) =~ "/sitemap-grids.xml"
    end

    test "grids and their topics enter and leave the sitemap as they cross the size threshold", %{
      conn: conn
    } do
      grid =
        developed_graph(%{title: "Growing community grid", data: grid_data(20)})
        |> Ecto.Changeset.change(tags: ["DevelopingTopic"])
        |> Repo.update!()

      refute conn |> get("/sitemap.xml") |> response(200) =~ "/sitemap-grids.xml"
      refute conn |> get("/sitemap.xml") |> response(200) =~ "/sitemap-topics.xml"
      assert conn |> get("/sitemap-topics.xml") |> response(200) |> locations() == []

      grid = grid |> Ecto.Changeset.change(data: grid_data(21)) |> Repo.update!()
      index = conn |> get("/sitemap.xml") |> response(200)
      assert index =~ "/sitemap-grids.xml?page=1"
      assert index =~ "/sitemap-topics.xml?page=1"
      assert conn |> get("/sitemap-grids.xml") |> response(200) =~ "/g/#{grid.slug}"
      assert conn |> get("/sitemap-topics.xml") |> response(200) =~ "?tag=developingtopic"

      grid |> Ecto.Changeset.change(data: grid_data(20)) |> Repo.update!()
      assert conn |> get("/sitemap-grids.xml") |> response(200) |> locations() == []
      assert conn |> get("/sitemap-topics.xml") |> response(200) |> locations() == []
    end

    test "lists exactly one canonical reader URL for each graph", %{conn: conn} do
      graph =
        developed_graph(%{title: "Single Canonical Graph", is_public: true, is_published: true})

      conn = get(conn, "/sitemap-grids.xml")
      body = conn.resp_body
      reader_url = DialecticWeb.Endpoint.url() <> "/g/#{graph.slug}"

      assert length(Regex.scan(~r/#{Regex.escape(reader_url)}/, body)) == 1
      refute body =~ reader_url <> "/graph"
      refute body =~ reader_url <> "?node="
    end

    test "excludes private graphs", %{conn: conn} do
      graph =
        developed_graph(%{title: "Private Graph Test", is_public: false, is_published: true})

      conn = get(conn, "/sitemap-grids.xml")

      body = conn.resp_body
      refute body =~ "/g/#{graph.slug}"
    end

    test "excludes unpublished graphs", %{conn: conn} do
      graph =
        developed_graph(%{title: "Unpublished Graph Test", is_public: true, is_published: false})

      conn = get(conn, "/sitemap-grids.xml")

      body = conn.resp_body
      refute body =~ "/g/#{graph.slug}"
    end

    test "excludes soft-deleted graphs", %{conn: conn} do
      graph =
        developed_graph(%{
          title: "Deleted Graph Test",
          is_public: true,
          is_published: true,
          is_deleted: true
        })

      conn = get(conn, "/sitemap-grids.xml")

      body = conn.resp_body
      refute body =~ "/g/#{graph.slug}"
    end

    test "excludes graphs with empty slugs", %{conn: conn} do
      # Insert directly to bypass slug validation
      Repo.insert!(%Graph{
        title: "No Slug Graph Test",
        data: grid_data(21),
        is_public: true,
        is_published: true,
        is_locked: false,
        is_deleted: false,
        slug: "",
        prompt_mode: "university"
      })

      conn = get(conn, "/sitemap-grids.xml")

      body = conn.resp_body
      refute body =~ "No Slug Graph Test"
    end

    test "excludes graphs with nil slugs", %{conn: conn} do
      Repo.insert!(%Graph{
        title: "Nil Slug Graph Test",
        data: grid_data(21),
        is_public: true,
        is_published: true,
        is_locked: false,
        is_deleted: false,
        slug: nil,
        prompt_mode: "university"
      })

      conn = get(conn, "/sitemap-grids.xml")

      body = conn.resp_body
      refute body =~ "Nil Slug Graph Test"
    end

    test "includes lastmod date for graphs", %{conn: conn} do
      developed_graph(%{title: "Dated Graph Test", is_public: true, is_published: true})

      conn = get(conn, "/sitemap-grids.xml")

      body = conn.resp_body
      assert body =~ ~r/<lastmod>\d{4}-\d{2}-\d{2}<\/lastmod>/
    end

    test "includes one canonical URL per nonempty public topic", %{conn: conn} do
      developed_graph(%{title: "Topic sitemap graph"})
      |> Ecto.Changeset.change(tags: ["Sociology", " sociology ", "Law & Society", "", " "])
      |> Repo.update!()

      for {title, attrs} <- [
            {"PrivateTopic", %{is_public: false}},
            {"DraftTopic", %{is_published: false}},
            {"DeletedTopic", %{is_deleted: true}}
          ] do
        developed_graph(Map.put(attrs, :title, title))
        |> Ecto.Changeset.change(tags: [title])
        |> Repo.update!()
      end

      body = conn |> get("/sitemap-topics.xml") |> response(200)
      base_url = DialecticWeb.Endpoint.url()

      assert length(
               Regex.scan(
                 ~r/<loc>#{Regex.escape(base_url)}\/community\?tag=sociology<\/loc>/,
                 body
               )
             ) == 1

      assert body =~ "<loc>#{base_url}/community?tag=law+%26+society</loc>"
      refute body =~ "?tag=Sociology"
      refute body =~ "?tag=</loc>"
      refute body =~ "?tag=privatetopic"
      refute body =~ "?tag=drafttopic"
      refute body =~ "?tag=deletedtopic"
    end

    test "topic entries reflect the current database on each request", %{conn: conn} do
      topic_url = DialecticWeb.Endpoint.url() <> "/community?tag=newtopic"
      refute conn |> get("/sitemap-topics.xml") |> response(200) =~ topic_url

      graph =
        developed_graph(%{title: "Newly published topic"})
        |> Ecto.Changeset.change(tags: ["NewTopic"])
        |> Repo.update!()

      assert conn |> get("/sitemap-topics.xml") |> response(200) =~ topic_url

      graph |> Ecto.Changeset.change(is_published: false) |> Repo.update!()
      refute conn |> get("/sitemap-topics.xml") |> response(200) =~ topic_url
    end

    test "does not emit backslash characters in output", %{conn: conn} do
      developed_graph(%{title: "Backslash Check Test", is_public: true, is_published: true})

      conn = get(conn, "/sitemap-grids.xml")

      body = conn.resp_body
      refute body =~ "\\"
    end
  end

  defp developed_graph(attrs) do
    insert_graph(Map.put_new(attrs, :data, grid_data(21)))
  end

  defp grid_data(count) do
    nodes = for index <- 1..count//1, do: %{"id" => to_string(index)}
    %{"nodes" => nodes, "edges" => []}
  end

  defp locations(xml) do
    for [_, location] <- Regex.scan(~r/<loc>([^<]+)<\/loc>/, xml), do: location
  end
end
