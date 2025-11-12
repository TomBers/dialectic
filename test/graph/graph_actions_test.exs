defmodule Dialectic.Graph.IntegrationGraphActionsTest do
  use DialecticWeb.ConnCase, async: false
  alias Dialectic.Graph.GraphActions
  alias Dialectic.Graph.Vertex

  @graph_id "TestGraph"
  @test_user "Bob"

  setup do
    GraphManager.reset_graph(@graph_id)
    Dialectic.GraphFixtures.insert_graph_fixture(@graph_id)

    graph = GraphManager.get_graph(@graph_id)
    {:ok, graph: graph}
  end

  def graph_param(node), do: {@graph_id, node, @test_user, nil}

  def inital_qa() do
    node = GraphActions.create_new_node(@test_user)

    new_node = GraphActions.comment(graph_param(node), "What is the meaning of life?")

    answer_node = GraphActions.answer(graph_param(new_node))
    {GraphManager.get_graph(@graph_id) |> elem(1), answer_node}
  end

  def branched_graph() do
    {_graph, answer} = inital_qa()
    _ = GraphActions.branch(graph_param(answer))
    {GraphManager.get_graph(@graph_id) |> elem(1), answer}
  end

  # Example of a full graph, with a question, answer, thesis, antithesis, and synthesis
  def full_graph() do
    {_, branched_node} = branched_graph()
    synth_node = GraphActions.combine(graph_param(branched_node), "3")

    comment_node =
      GraphActions.comment(graph_param(synth_node), "What is the meaning of life?")

    _ = GraphActions.answer(graph_param(comment_node))
    {GraphManager.get_graph(@graph_id) |> elem(1), synth_node}
  end

  test "full graph has expected properties", %{graph: _} do
    {graph, _} = full_graph()
    # q1, a1, thesis, antithesis, synthesis, synthesis question, synthesis answer
    assert length(:digraph.vertices(graph)) == 7

    # q1 -> a1, a1 -> thesis, a1 -> antithesis, thesis -> synthesis, antithesis -> synthesis, synthesis -> synthesis question, synthesis question -> synthesis answer
    assert length(:digraph.edges(graph)) == 7

    nodes = ["1", "2", "3", "4", "5", "6", "7"]
    answers = ["user", "answer", "thesis", "antithesis", "synthesis", "user", "answer"]

    Enum.with_index(nodes, fn node_id, index ->
      node = GraphActions.find_node(@graph_id, node_id)
      assert node.class == Enum.at(answers, index)
    end)
  end

  test "create_new_node creates vertex with correct properties" do
    node = GraphActions.create_new_node(@test_user)
    assert %Vertex{} = node
    assert node.user == @test_user
    assert String.starts_with?(node.id, "NewNode")
    assert node.parents == []
  end

  test "answer creates question and answer nodes", %{graph: _} do
    root_node = GraphActions.create_new_node(@test_user)

    cnode = GraphActions.comment(graph_param(root_node), "Test question?")

    _answer_node = GraphActions.answer(graph_param(cnode))

    {_, updated_graph} = GraphManager.get_graph(@graph_id)
    vertices = :digraph.vertices(updated_graph)
    # root, question, and answer nodes
    assert length(vertices) == 2

    # Verify the last two nodes are question and answer
    question_node = GraphActions.find_node(@graph_id, "1")
    answer_node = GraphActions.find_node(@graph_id, "2")

    assert question_node.class == "user"
    assert answer_node.class == "answer"
  end

  test "branch creates thesis and antithesis nodes", %{graph: _} do
    {_graph, answer_node} = inital_qa()
    _ = GraphActions.branch(graph_param(answer_node))

    {_, updated_graph} = GraphManager.get_graph(@graph_id)
    vertices = :digraph.vertices(updated_graph)
    # initial QA (2) + thesis + antithesis
    assert length(vertices) == 4

    # Verify thesis and antithesis nodes
    thesis_node = GraphActions.find_node(@graph_id, "3")
    antithesis_node = GraphActions.find_node(@graph_id, "4")

    assert thesis_node.class == "thesis"
    assert antithesis_node.class == "antithesis"
  end

  test "combine creates synthesis node with two parents", %{graph: _} do
    {_, node1} = branched_graph()

    synthesis_node =
      GraphActions.combine(graph_param(node1), "3")

    # Verify synthesis node properties
    assert synthesis_node.class == "synthesis"
    assert length(synthesis_node.parents) == 2

    # Verify graph structure
    # QA (2) + thesis/antithesis (2) + synthesis
    {_, updated_graph} = GraphManager.get_graph(@graph_id)
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
    inital_qa()
    found_node = GraphActions.find_node(@graph_id, "2")
    assert found_node.id == "2"
    assert found_node.class == "answer"
  end

  test "find_node returns nil for non-existent node" do
    result = GraphActions.find_node(@graph_id, "non-existent")
    assert result == nil
  end

  test "answer maintains correct parent relationships", %{graph: _} do
    {_, answer_node} = inital_qa()
    question_node = GraphActions.find_node(@graph_id, "1")

    # Verify parent-child relationships
    {_, updated_graph} = GraphManager.get_graph(@graph_id)
    edges = :digraph.edges(updated_graph)
    # root->question, question->answer
    assert length(edges) == 1

    # Verify answer node's parent is the question node
    assert length(answer_node.parents) == 1
    [parent] = answer_node.parents
    assert parent.id == question_node.id
  end

  test "graph maintains correct structure through multiple operations", %{graph: _} do
    # Create initial QA
    {_, answer1} = inital_qa()
    {_, g1} = GraphManager.get_graph(@graph_id)
    assert length(:digraph.vertices(g1)) == 2

    _ = GraphActions.branch(graph_param(answer1))
    {_, g2} = GraphManager.get_graph(@graph_id)
    assert length(:digraph.vertices(g2)) == 4

    synthesis = GraphActions.combine(graph_param(answer1), "3")
    {_, g3} = GraphManager.get_graph(@graph_id)
    assert length(:digraph.vertices(g3)) == 5

    _ =
      GraphActions.answer(graph_param(synthesis))

    {_, g4} = GraphManager.get_graph(@graph_id)
    assert length(:digraph.vertices(g4)) == 6

    # Verify final structure
    assert length(:digraph.edges(g4)) == 6
  end
end
