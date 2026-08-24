defmodule DialecticWeb.HighlightShareTest do
  use ExUnit.Case, async: true

  alias DialecticWeb.HighlightShare

  describe "share paths" do
    test "fall back to encoded graph title when slug is nil" do
      graph = %{title: "Graph Title With Spaces", slug: nil, is_public: true}
      highlight = %{id: 42, node_id: "7"}

      assert HighlightShare.share_path(graph, highlight) ==
               "/g/Graph%20Title%20With%20Spaces?node=7&highlight=42"
    end

    test "fall back to encoded graph title when slug is blank" do
      graph = %{title: "Graph/Title? With Reserved", slug: "", is_public: true}
      highlight = %{id: 42, node_id: "7"}

      assert HighlightShare.share_path(graph, highlight) ==
               "/g/Graph%2FTitle%3F%20With%20Reserved?node=7&highlight=42"
    end

    test "fallback share paths include private graph token" do
      graph = %{
        title: "Private Legacy Graph",
        slug: nil,
        is_public: false,
        share_token: "secret-token"
      }

      highlight = %{id: 42, node_id: "7"}
      path = HighlightShare.share_path(graph, highlight)

      assert String.starts_with?(path, "/g/Private%20Legacy%20Graph?")

      assert URI.decode_query(URI.parse(path).query) == %{
               "node" => "7",
               "highlight" => "42",
               "token" => "secret-token"
             }
    end
  end

  describe "image paths" do
    test "uses the same image API for grid and quote cards" do
      graph = %{title: "Graph Title", slug: "graph-title-123", is_public: true}
      highlight = %{id: 42}

      assert HighlightShare.image_path(graph) == "/g/graph-title-123/share-card.svg?sv=19"

      assert HighlightShare.image_path(graph, highlight) ==
               "/g/graph-title-123/highlights/42/share-card.svg?sv=19"

      assert HighlightShare.image_url(graph) =~ "/g/graph-title-123/share-card.svg?sv=19"
      assert HighlightShare.image_url(graph, highlight) =~ "/highlights/42/share-card.svg?sv=19"
    end

    test "fall back to encoded graph title when slug is nil" do
      graph = %{title: "Graph Title With Spaces", slug: nil, is_public: true}
      highlight = %{id: 42}

      assert HighlightShare.image_path(graph, highlight) ==
               "/g/Graph%20Title%20With%20Spaces/highlights/42/share-card.svg?sv=19"
    end

    test "fallback image paths include private graph token" do
      graph = %{
        title: "Private Legacy Graph",
        slug: nil,
        is_public: false,
        share_token: "secret-token"
      }

      highlight = %{id: 42}
      path = HighlightShare.image_path(graph, highlight)

      assert String.starts_with?(
               path,
               "/g/Private%20Legacy%20Graph/highlights/42/share-card.svg?"
             )

      assert URI.decode_query(URI.parse(path).query) == %{
               "sv" => "19",
               "token" => "secret-token"
             }
    end

    test "adds the portrait format without changing the default landscape path" do
      graph = %{title: "Graph Title", slug: "graph-title-123", is_public: true}

      assert URI.decode_query(URI.parse(HighlightShare.image_path(graph)).query) == %{
               "sv" => "19"
             }

      assert URI.decode_query(
               URI.parse(HighlightShare.image_path(graph, nil, orientation: :portrait)).query
             ) == %{
               "orientation" => "portrait",
               "sv" => "19"
             }
    end
  end

  describe "image svg" do
    test "generates grid and quote cards through the same image function" do
      graph = %{title: "One image interface", data: %{"nodes" => []}}
      highlight = %{id: 9, node_id: "1", selected_text_snapshot: "A quoted idea"}

      assert HighlightShare.image_svg(graph) =~ "One image interface"
      assert HighlightShare.image_svg(graph, highlight) =~ "A quoted idea"
    end

    test "uses the highlight renderer and wrapping algorithm for long grid titles" do
      graph = %{
        title:
          "Discuss the fairness and public ethics around reserving seats and tables in public spaces by putting coats and bags on them",
        data: %{"nodes" => []}
      }

      svg = HighlightShare.image_svg(graph)
      lines = quote_lines(svg)

      assert length(lines) >= 2
      assert Enum.join(lines, " ") =~ "Discuss the fairness and public ethics"
      assert svg =~ ~s(id="quoteCanvas")
      assert svg =~ ~s(fill="#fff7ed")
      refute svg =~ ">Grid on RationalGrid</text>"
      assert length(Regex.scan(~r/>RationalGrid\.ai<\/text>/, svg)) == 1
      assert svg =~ "data:image/png;base64,"
    end

    test "renders portrait cards through the same style and content path" do
      graph = %{title: "Portrait social card", data: %{"nodes" => []}}
      svg = HighlightShare.image_svg(graph, nil, orientation: :portrait)

      assert svg =~ ~s(width="1080" height="1350")
      assert svg =~ ~s(viewBox="0 0 1200 1500")
      assert svg =~ ~s(data-orientation="portrait")
      assert svg =~ ~s(id="quoteCanvas")
      assert quote_lines(svg) == ["Portrait social card"]
      assert length(Regex.scan(~r/>RationalGrid\.ai<\/text>/, svg)) == 1
    end

    test "balances short quote lines across the share card" do
      graph = %{
        title: "Capitalism and Schizophrenia (Deleuze and Guattari)",
        slug: "capitalism-and-schizophrenia-deleuze-and-guattari-e7527d",
        is_public: true,
        data: %{
          "nodes" => [
            %{
              "id" => 20,
              "content" => "# Primary Sources and Structural Mechanisms of the Big Other\n\nBody"
            }
          ]
        }
      }

      highlight = %{
        id: 107,
        node_id: 20,
        selected_text_snapshot: "The unconscious is that part of the concrete discourse"
      }

      svg = HighlightShare.image_svg(graph, highlight)

      assert quote_lines(svg) == [
               "The unconscious is that part",
               "of the concrete discourse"
             ]

      refute String.contains?(svg, "HIGHLIGHTED INSIGHT")

      assert String.contains?(
               svg,
               ">Primary Sources and Structural Mechanisms of the Big Other</text>"
             )
    end
  end

  describe "node titles" do
    test "returns the complete node title for share cards" do
      title =
        "A complete and deliberately long node title that should remain intact instead of being shortened for the share image attribution area"

      graph = %{
        data: %{"nodes" => [%{"id" => "7", "content" => "# #{title}\n\nBody"}]}
      }

      assert HighlightShare.node_title(graph, "7") == title
    end
  end

  defp quote_lines(svg) do
    [_, quote_block] = Regex.run(~r/<text fill="#fff7ed"[^>]*>(.*?)<\/text>/s, svg)

    ~r/<tspan\b[^>]*>([^<]+)<\/tspan>/
    |> Regex.scan(quote_block)
    |> Enum.map(&Enum.at(&1, 1))
  end
end
