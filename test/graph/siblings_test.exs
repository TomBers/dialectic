defmodule Graph.SiblingsTest do
  alias Dialectic.Graph.Siblings
  use DialecticWeb.ConnCase, async: false

  @graph_id "SiblingsTestGraph"

  setup do
    # Ensure graph is removed from registry before each test
    GraphManager.reset_graph(@graph_id)

    # Build a small programmatic graph instead of relying on static JSON files
    data = %{
      "nodes" => [
        %{
          "id" => "1",
          "content" => "Root",
          "class" => "origin",
          "user" => nil,
          "parent" => nil,
          "noted_by" => [],
          "deleted" => false,
          "compound" => false
        },
        %{
          "id" => "2",
          "content" => "Child A",
          "class" => "user",
          "user" => nil,
          "parent" => nil,
          "noted_by" => [],
          "deleted" => false,
          "compound" => false
        },
        %{
          "id" => "3",
          "content" => "Child B",
          "class" => "user",
          "user" => nil,
          "parent" => nil,
          "noted_by" => [],
          "deleted" => false,
          "compound" => false
        },
        %{
          "id" => "4",
          "content" => "Child C",
          "class" => "user",
          "user" => nil,
          "parent" => nil,
          "noted_by" => [],
          "deleted" => false,
          "compound" => false
        }
      ],
      "edges" => [
        %{"data" => %{"id" => "1_2", "source" => "1", "target" => "2"}},
        %{"data" => %{"id" => "1_3", "source" => "1", "target" => "3"}},
        %{"data" => %{"id" => "1_4", "source" => "1", "target" => "4"}}
      ]
    }

    Dialectic.GraphFixtures.insert_data(data, @graph_id)
    :ok
  end

  test "up/left/right and sibling sorting work against a simple programmatic graph" do
    # Ensure graph server is started and grab the in-memory graph
    {_, graph} = GraphManager.get_graph(@graph_id)

    # Pick middle child "3" and verify parent lookup
    node = GraphManager.find_node_by_id(@graph_id, "3")
    assert Siblings.up(node).id == "1"

    # Sibling sorting is deterministic
    siblings = Siblings.sort_siblings(node, graph)
    assert Enum.map(siblings, & &1.id) == ["2", "3", "4"]

    # Navigation among siblings
    assert Siblings.left(node, graph).id == "2"
    assert Siblings.right(node, graph).id == "4"

    # Edge cases: first stays first on left, last stays last on right
    first = GraphManager.find_node_by_id(@graph_id, "2")
    assert Siblings.left(first, graph).id == "2"

    last = GraphManager.find_node_by_id(@graph_id, "4")
    assert Siblings.right(last, graph).id == "4"
  end
end
