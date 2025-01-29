defmodule Dialectic.Graph.GraphActions do
  alias Dialectic.Graph.Vertex
  alias Dialectic.Responses.LlmInterface

  def create_new_node(user) do
    %Vertex{user: user, id: "NewNode"}
  end

  def answer(graph_id, node, question, user, pid) do
    parents = if length(node.parents) == 0, do: [], else: [node]

    {_g, question_node} =
      GraphManager.add_child(
        graph_id,
        parents,
        fn n -> LlmInterface.add_question(question, n, pid) end,
        "user",
        user
      )

    GraphManager.add_child(
      graph_id,
      [question_node],
      fn n -> LlmInterface.gen_response(question, question_node, n, pid) end,
      "answer",
      user
    )
  end

  def branch(graph_id, node, user, pid) do
    GraphManager.add_child(
      graph_id,
      [node],
      fn n -> LlmInterface.gen_thesis(node, n, pid) end,
      "thesis",
      user
    )

    GraphManager.add_child(
      graph_id,
      [node],
      fn n -> LlmInterface.gen_antithesis(node, n, pid) end,
      "antithesis",
      user
    )
  end

  def combine(graph_id, node1, combine_node_id, user, pid) do
    case GraphManager.find_node_by_id(graph_id, combine_node_id) do
      nil ->
        nil

      {_g, node2} ->
        GraphManager.add_child(
          graph_id,
          [node1, node2],
          fn n -> LlmInterface.gen_synthesis(node1, node2, n, pid) end,
          "synthesis",
          user
        )
    end
  end

  def find_node(graph_id, id) do
    GraphManager.find_node_by_id(graph_id, id)
  end
end
