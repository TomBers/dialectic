defmodule Dialectic.Graph.GraphActionsTest do
  use ExUnit.Case
  alias Dialectic.Graph.GraphActions
  alias Dialectic.Graph.Vertex

  setup do
    graph = GraphActions.new_graph()
    {:ok, graph: graph}
  end

  # Test 1: Adding an answer from an empty graph
  test "answer/3 adds a question and answer node to an empty graph", %{graph: graph} do
    # Create a root node
    root_node = GraphActions.add_node(graph, "root", "root content", "root class")

    # Add an answer to the root node
    {graph, _} = GraphActions.answer(graph, root_node, "What is the meaning of life?")

    # Verify the graph structure
    # Root, question, answer
    assert length(:digraph.vertices(graph)) == 3
    # Root -> question, question -> answer
    assert length(:digraph.edges(graph)) == 2
  end

  # Test 2: Adding an answer from an existing graph
  test "answer/3 adds a question and answer node to an existing graph", %{graph: graph} do
    # Create a root node and an initial answer
    root_node = GraphActions.add_node(graph, "root", "root content", "root class")
    {graph, _} = GraphActions.answer(graph, root_node, "Initial question")

    # Add another answer to the root node
    {graph, _} = GraphActions.answer(graph, root_node, "Follow-up question")

    # Verify the graph structure
    # Root, 2 questions, 2 answers
    assert length(:digraph.vertices(graph)) == 5
    # Root -> Q1, Q1 -> A1, Root -> Q2, Q2 -> A2
    assert length(:digraph.edges(graph)) == 4
  end

  # Test 3: Branching from a node
  test "branch/2 adds a thesis and antithesis node", %{graph: graph} do
    # Create a root node
    root_node = GraphActions.add_node(graph, "root", "root content", "root class")

    # Branch from the root node
    {graph, _} = GraphActions.branch(graph, root_node)

    # Verify the graph structure
    # Root, thesis, antithesis
    assert length(:digraph.vertices(graph)) == 3
    # Root -> thesis, Root -> antithesis
    assert length(:digraph.edges(graph)) == 2
  end

  # Test 4: Combining two nodes
  test "combine/3 adds a synthesis node", %{graph: graph} do
    # Create two nodes to combine
    node1 = GraphActions.add_node(graph, "node1", "content1", "class1")
    node2 = GraphActions.add_node(graph, "node2", "content2", "class2")

    # Combine the two nodes
    {graph, _} = GraphActions.combine(graph, node1, node2.id)

    # Verify the graph structure
    # node1, node2, synthesis
    assert length(:digraph.vertices(graph)) == 4
    # node1 -> synthesis, node2 -> synthesis
    assert length(:digraph.edges(graph)) == 2
  end

  # Test 5: Adding answers from a branched node
  test "answer/3 adds a question and answer node from a branched node", %{graph: graph} do
    # Create a root node and branch from it
    root_node = GraphActions.add_node(graph, "root", "root content", "root class")
    {graph, _} = GraphActions.branch(graph, root_node)

    # Find the thesis node
    thesis_node = Vertex.find_node_by_id(graph, "1")

    # Add an answer to the thesis node
    {graph, _} = GraphActions.answer(graph, thesis_node, "Question about thesis")

    # Verify the graph structure
    # Root, thesis, antithesis, question, answer
    assert length(:digraph.vertices(graph)) == 5
    # Root -> thesis, Root -> antithesis, thesis -> question, question -> answer
    assert length(:digraph.edges(graph)) == 4
  end

  # Test 6: Adding answers from a synthesis node
  test "answer/3 adds a question and answer node from a synthesis node", %{graph: graph} do
    # Create two nodes and combine them
    node1 = GraphActions.add_node(graph, "node1", "content1", "class1")
    node2 = GraphActions.add_node(graph, "node2", "content2", "class2")
    {graph, _} = GraphActions.combine(graph, node1, node2.id)

    # Find the synthesis node
    synthesis_node = Vertex.find_node_by_id(graph, "3")

    # Add an answer to the synthesis node
    {graph, _} = GraphActions.answer(graph, synthesis_node, "Question about synthesis")

    # Verify the graph structure
    # node1, node2, synthesis, question, answer
    assert length(:digraph.vertices(graph)) == 6
    # node1 -> synthesis, node2 -> synthesis, synthesis -> question, question -> answer
    assert length(:digraph.edges(graph)) == 4
  end
end
