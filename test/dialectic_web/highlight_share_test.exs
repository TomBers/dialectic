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
    test "fall back to encoded graph title when slug is nil" do
      graph = %{title: "Graph Title With Spaces", slug: nil, is_public: true}
      highlight = %{id: 42}

      assert HighlightShare.image_path(graph, highlight) ==
               "/g/Graph%20Title%20With%20Spaces/highlights/42/share-card.svg?sv=11"
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
               "sv" => "11",
               "token" => "secret-token"
             }
    end
  end
end
