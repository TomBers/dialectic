defmodule Graph.SiblingsTest do
  alias Dialectic.Graph.Siblings
  use DialecticWeb.ConnCase, async: false

  @graph_id "Big graph"

  setup do
    # Ensure graph is removed from registry before each test
    GraphManager.reset_graph(@graph_id)
    # Also create test database
    Dialectic.GraphFixtures.insert_graph_fixture(@graph_id)
    :ok
  end

  test "can get parent and child" do
    GraphManager.get_graph(@graph_id)
    assert GraphManager.exists?(@graph_id)

    {_, node} = GraphManager.find_node_by_id(@graph_id, "4")
    parent = Siblings.up(node)
    assert parent.id == "3"

    child = Siblings.down(node)
    assert child.id == "5"

    # A sibling with lots of siblings
    {graph, node} = GraphManager.find_node_by_id(@graph_id, "6")
    siblings = Siblings.sort_siblings(node, graph)
    assert Enum.map(siblings, fn n -> n.id end) == ["6", "aa9", "ad1", "ad3", "ao4", "an3"]
    assert Siblings.left(node, graph).id == "6"
    assert Siblings.right(node, graph).id == "aa9"

    {graph, last_node} = GraphManager.find_node_by_id(@graph_id, "an3")
    assert Siblings.right(last_node, graph).id == "an3"
  end
end
