defmodule Dialectic.ContentTest do
  use Dialectic.DataCase, async: true

  alias Dialectic.Content
  alias Dialectic.GraphFixtures

  describe "promotion material" do
    test "lists public graphs and hides private/deleted graphs" do
      public_graph = GraphFixtures.insert_graph(%{title: "Public Promotion Graph"})

      _private_graph =
        GraphFixtures.insert_graph(%{title: "Private Promotion Graph", is_public: false})

      _deleted_graph =
        GraphFixtures.insert_graph(%{title: "Deleted Promotion Graph", is_deleted: true})

      results = Content.list_public_graphs()
      titles = Enum.map(results, fn {graph, _node_count} -> graph.title end)

      assert public_graph.title in titles
      refute "Private Promotion Graph" in titles
      refute "Deleted Promotion Graph" in titles
    end

    test "public graph node count handles missing or non-array nodes" do
      graph =
        GraphFixtures.insert_graph(%{
          title: "Malformed Nodes Promotion Graph",
          data: %{"nodes" => %{"not" => "a list"}, "edges" => []}
        })

      assert {_listed_graph, 0} =
               Content.list_public_graphs()
               |> Enum.find(fn {listed_graph, _node_count} ->
                 listed_graph.title == graph.title
               end)
    end

    test "gets public graph by slug or title" do
      graph = GraphFixtures.insert_graph(%{title: "Get Public Promotion Graph"})

      assert Content.get_public_graph_by_slug_or_title(graph.slug).title == graph.title
      assert Content.get_public_graph_by_slug_or_title(graph.title).slug == graph.slug
      assert is_nil(Content.get_public_graph_by_slug_or_title("missing"))
    end
  end
end
