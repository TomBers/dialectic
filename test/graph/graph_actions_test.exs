defmodule Dialectic.Graph.GraphActionsTest do
  use ExUnit.Case
  alias Dialectic.Graph.GraphActions
  alias Dialectic.Graph.Vertex

  @graph_id "TestGraph"
  @test_user "Bob"

  setup do
    GraphManager.reset_graph(@graph_id)
    graph = GraphManager.get_graph(@graph_id)
    {:ok, graph: graph}
  end

  def graph_param(node), do: {@graph_id, node, @test_user, self()}

  def inital_qa() do
    node = GraphActions.create_new_node(@test_user)

    GraphActions.comment(graph_param(node), "What is the meaning of life?")

    GraphActions.answer(graph_param(node))
  end

  def branched_graph() do
    {_graph, answer} = inital_qa()
    GraphActions.branch(graph_param(answer))
  end

  # Example of a full graph, with a question, answer, thesis, antithesis, and synthesis
  def full_graph() do
    {_, branched_node} = branched_graph()
    {_, synth_node} = GraphActions.combine(graph_param(branched_node), "3")

    {_, comment_node} =
      GraphActions.comment(graph_param(synth_node), "What is the meaning of life?")

    GraphActions.answer(graph_param(comment_node))
  end

  test "full graph has expected properties", %{graph: graph} do
    {graph, _} = full_graph()
    # q1, a1, thesis, antithesis, synthesis, synthesis question, synthesis answer
    assert length(:digraph.vertices(graph)) == 7

    # q1 -> a1, a1 -> thesis, a1 -> antithesis, thesis -> synthesis, antithesis -> synthesis, synthesis -> synthesis question, synthesis question -> synthesis answer
    assert length(:digraph.edges(graph)) == 7

    nodes = ["1", "2", "3", "4", "5", "6", "7"]
    answers = ["user", "answer", "thesis", "antithesis", "synthesis", "user", "answer"]

    Enum.with_index(nodes, fn node_id, index ->
      {_, node} = GraphActions.find_node(@graph_id, node_id)
      assert node.class == Enum.at(answers, index)
    end)
  end

  test "create_new_node creates vertex with correct properties" do
    node = GraphActions.create_new_node(@test_user)
    assert %Vertex{} = node
    assert node.user == @test_user
    assert node.id == "NewNode"
    assert node.parents == []
  end

  test "answer creates question and answer nodes", %{graph: graph} do
    root_node = GraphActions.create_new_node(@test_user)

    {_, cnode} = GraphActions.comment(graph_param(root_node), "Test question?")

    {updated_graph, _answer_node} =
      GraphActions.answer(graph_param(cnode))

    vertices = :digraph.vertices(updated_graph)
    # root, question, and answer nodes
    assert length(vertices) == 2

    # Verify the last two nodes are question and answer
    {_, question_node} = GraphActions.find_node(@graph_id, "1")
    {_, answer_node} = GraphActions.find_node(@graph_id, "2")

    assert question_node.class == "user"
    assert answer_node.class == "answer"
  end

  test "branch creates thesis and antithesis nodes", %{graph: graph} do
    {_graph, answer_node} = inital_qa()
    {updated_graph, _} = GraphActions.branch(graph_param(answer_node))

    vertices = :digraph.vertices(updated_graph)
    # initial QA (2) + thesis + antithesis
    assert length(vertices) == 4

    # Verify thesis and antithesis nodes
    {_, thesis_node} = GraphActions.find_node(@graph_id, "3")
    {_, antithesis_node} = GraphActions.find_node(@graph_id, "4")

    assert thesis_node.class == "thesis"
    assert antithesis_node.class == "antithesis"
  end

  test "combine creates synthesis node with two parents", %{graph: graph} do
    {_, node1} = branched_graph()

    {updated_graph, synthesis_node} =
      GraphActions.combine(graph_param(node1), "3")

    # Verify synthesis node properties
    assert synthesis_node.class == "synthesis"
    assert length(synthesis_node.parents) == 2

    # Verify graph structure
    # QA (2) + thesis/antithesis (2) + synthesis
    assert length(:digraph.vertices(updated_graph)) == 5
    # QA edge + thesis/antithesis edges (2) + synthesis edges (2)
    assert length(:digraph.edges(updated_graph)) == 5
  end

  test "combine returns nil for non-existent node" do
    {_, node1} = inital_qa()
    result = GraphActions.combine(graph_param(node1), "non-existent")
    assert result == nil
  end

  test "find_node returns correct node" do
    {_graph, answer_node} = inital_qa()
    {_graph, found_node} = GraphActions.find_node(@graph_id, "2")
    assert found_node.id == "2"
    assert found_node.class == "answer"
  end

  test "find_node returns nil for non-existent node" do
    result = GraphActions.find_node(@graph_id, "non-existent")
    assert result == nil
  end

  test "answer maintains correct parent relationships", %{graph: graph} do
    {updated_graph, answer_node} = inital_qa()
    {_, question_node} = GraphActions.find_node(@graph_id, "1")

    # Verify parent-child relationships
    edges = :digraph.edges(updated_graph)
    # root->question, question->answer
    assert length(edges) == 1

    # Verify answer node's parent is the question node
    assert length(answer_node.parents) == 1
    [parent] = answer_node.parents
    assert parent.id == question_node.id
  end

  test "graph maintains correct structure through multiple operations", %{graph: graph} do
    # Create initial QA
    {g1, answer1} = inital_qa()
    assert length(:digraph.vertices(g1)) == 2

    # Branch from answer
    {g2, _} = GraphActions.branch(graph_param(answer1))
    assert length(:digraph.vertices(g2)) == 4

    # Create synthesis
    {g3, synthesis} = GraphActions.combine(graph_param(answer1), "3")
    assert length(:digraph.vertices(g3)) == 5

    # Add another QA to synthesis
    {g4, _} =
      GraphActions.answer(graph_param(synthesis))

    assert length(:digraph.vertices(g4)) == 7

    # Verify final structure
    assert length(:digraph.edges(g4)) == 7
  end
end
