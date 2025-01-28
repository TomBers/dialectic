defmodule Dialectic.Graph.GraphActionsTest do
  use ExUnit.Case
  alias Dialectic.Graph.GraphActions
  alias Dialectic.Graph.Vertex

  setup do
    graph = GraphActions.new_graph()
    {:ok, graph: graph}
  end

  def inital_qa(graph) do
    root_node = GraphActions.create_new_node(graph)
    GraphActions.answer(graph, root_node, "What is the meaning of life?", self())
  end

  def branched_graph(graph) do
    {graph, answer} = inital_qa(graph)
    GraphActions.branch(graph, answer, self())
  end

  # Example of a full graph, with a question, answer, thesis, antithesis, and synthesis
  def full_graph(graph) do
    {graph, branched_node} = branched_graph(graph)
    {graph, synth_node} = GraphActions.combine(graph, branched_node, "3", self())
    GraphActions.answer(graph, synth_node, "Synthesis question", self())
  end

  test "full graph has expected properties", %{graph: graph} do
    {graph, _} = full_graph(graph)
    # q1, a1, thesis, antithesis, synthesis, synthesis question, synthesis answer
    assert length(:digraph.vertices(graph)) == 7

    # q1 -> a1, a1 -> thesis, a1 -> antithesis, thesis -> synthesis, antithesis -> synthesis, synthesis -> synthesis question, synthesis question -> synthesis answer
    assert length(:digraph.edges(graph)) == 7

    assert Vertex.find_node_by_id(graph, "1").class == "user"
    assert Vertex.find_node_by_id(graph, "2").class == "answer"
    assert Vertex.find_node_by_id(graph, "3").class == "thesis"
    assert Vertex.find_node_by_id(graph, "4").class == "antithesis"
    assert Vertex.find_node_by_id(graph, "5").class == "synthesis"
    assert Vertex.find_node_by_id(graph, "6").class == "user"
    assert Vertex.find_node_by_id(graph, "7").class == "answer"
  end

  test "answer/3 adds a question and answer node to an empty graph", %{graph: graph} do
    root_node = GraphActions.create_new_node(graph)

    {graph, answer_node} =
      GraphActions.answer(graph, root_node, "What is the meaning of life?", self())

    # Root, question, answer
    assert length(:digraph.vertices(graph)) == 2
    # Root -> question, question -> answer
    assert length(:digraph.edges(graph)) == 1
    assert answer_node.content =~ "What is the meaning of life?"
    assert answer_node.class == "answer"
  end

  test "answer/3 adds a question and answer node to an existing graph", %{graph: graph} do
    root_node = GraphActions.create_new_node(graph)
    {graph, n1} = GraphActions.answer(graph, root_node, "Initial question", self())
    {graph, an} = GraphActions.answer(graph, n1, "Follow-up question", self())
    # 2 questions, 2 answers
    assert length(:digraph.vertices(graph)) == 4
    # Q1 -> A1, A1 -> Q2, Q2 -> A2
    assert length(:digraph.edges(graph)) == 3

    assert n1.class == "answer"
    assert an.class == "answer"
  end

  test "branch/2 adds a thesis and antithesis node", %{graph: graph} do
    root_node = GraphActions.create_new_node(graph)
    {graph, n1} = GraphActions.answer(graph, root_node, "What is the meaning of life?", self())
    {graph, tn} = GraphActions.branch(graph, n1, self())
    # Root, Answer, thesis, antithesis
    assert length(:digraph.vertices(graph)) == 4
    # Root -> Answer, Answer -> thesis, Answer -> antithesis
    assert length(:digraph.edges(graph)) == 3

    assert tn.class == "antithesis"
  end

  test "combine/3 adds a synthesis node", %{graph: graph} do
    {graph, branched_node} = branched_graph(graph)
    assert length(:digraph.vertices(graph)) == 4
    assert length(:digraph.edges(graph)) == 3

    {graph, synth_node} = GraphActions.combine(graph, branched_node, "3", self())
    # q1, a1, thesis, antithesis, synthesis
    assert length(:digraph.vertices(graph)) == 5
    # q1 -> a1, a1 -> thesis, a1 -> antithesis, thesis -> synthesis, antithesis -> synthesis
    assert length(:digraph.edges(graph)) == 5

    assert synth_node.class == "synthesis"

    # Test you can also answer the synthesis question
    {_, an} = GraphActions.answer(graph, synth_node, "Synthesis question", self())
    # q1, a1, thesis, antithesis, synthesis, synthesis question, synthesis answer
    assert length(:digraph.vertices(graph)) == 7

    # q1 -> a1, a1 -> thesis, a1 -> antithesis, thesis -> synthesis, antithesis -> synthesis, synthesis -> synthesis question, synthesis question -> synthesis answer
    assert length(:digraph.edges(graph)) == 7
    assert an.class == "answer"
  end

  test "answer/3 adds a question and answer node from a branched node", %{graph: graph} do
    {graph, root_node} = inital_qa(graph)
    assert length(:digraph.vertices(graph)) == 2
    assert length(:digraph.edges(graph)) == 1

    {graph, _} = GraphActions.branch(graph, root_node, self())
    assert length(:digraph.vertices(graph)) == 4
    assert length(:digraph.edges(graph)) == 3

    thesis_node = Vertex.find_node_by_id(graph, "3")
    {graph, _} = GraphActions.answer(graph, thesis_node, "Question about thesis", self())
    # # Root, answer, thesis, antithesis, theis question, answer
    assert length(:digraph.vertices(graph)) == 6

    # # Root -> answer, answer -> thesis, answer -> antithesis, thesis -> theis question, thesis question -> thesis answer
    assert length(:digraph.edges(graph)) == 4
  end
end
