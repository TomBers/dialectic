defmodule Dialectic.ContentTest do
  use Dialectic.DataCase, async: true

  alias Dialectic.Content
  alias Dialectic.GraphFixtures

  describe "promotion material" do
    test "lists public candidate graphs and hides private graphs" do
      public_graph = GraphFixtures.insert_graph(%{title: "Public Content Candidate"})

      _private_graph =
        GraphFixtures.insert_graph(%{title: "Private Content Candidate", is_public: false})

      results = Content.list_candidate_graphs("Content Candidate")
      titles = Enum.map(results, fn {graph, _node_count, _author} -> graph.title end)

      assert public_graph.title in titles
      refute "Private Content Candidate" in titles
    end

    test "candidate graph node count handles missing or non-array nodes" do
      graph =
        GraphFixtures.insert_graph(%{
          title: "Malformed Nodes Content Candidate",
          data: %{"nodes" => %{"not" => "a list"}, "edges" => []}
        })

      assert [{listed_graph, 0, _author}] = Content.list_candidate_graphs(graph.title)
      assert listed_graph.title == graph.title
    end

    test "summarizes graph nodes without deleted or compound nodes" do
      graph =
        GraphFixtures.insert_graph(%{
          title: "Node Summary Candidate",
          data: %{
            "nodes" => [
              %{"id" => "1", "content" => "## Main Question", "class" => "origin"},
              %{"id" => "2", "content" => "A useful answer", "class" => "answer"},
              %{"id" => "3", "content" => "Hidden", "class" => "answer", "deleted" => true},
              %{"id" => "4", "content" => "Group", "class" => "origin", "compound" => true}
            ],
            "edges" => []
          }
        })

      nodes =
        graph
        |> Content.graph_nodes()
        |> Enum.reject(&(Map.get(&1, "deleted") == true or Map.get(&1, "compound") == true))
        |> Enum.map(&Content.node_summary/1)
        |> Enum.sort_by(fn node -> {node.sort_class, node.title} end)

      assert Enum.map(nodes, & &1.id) == ["1", "2"]
      assert hd(nodes).title == "Main Question"
    end
  end
end
