defmodule Dialectic.Graph.GraphActions do
  alias Dialectic.Graph.Vertex
  alias Dialectic.Responses.LlmInterface

  def create_new_node(user) do
    %Vertex{user: user, id: "NewNode"}
  end

  def answer(graph_id, node, question, user) do
    parents = if length(node.parents) == 0, do: [], else: [node]

    {_g, question_node} =
      GraphManager.add_child(
        graph_id,
        parents,
        question,
        "user",
        user
      )

    GraphManager.add_child(
      graph_id,
      [question_node],
      LlmInterface.gen_response(question, node),
      "answer",
      user
    )
  end

  def branch(graph_id, node, user) do
    GraphManager.add_child(
      graph_id,
      [node],
      LlmInterface.gen_thesis(node),
      "thesis",
      user
    )

    GraphManager.add_child(
      graph_id,
      [node],
      LlmInterface.gen_antithesis(node),
      "antithesis",
      user
    )
  end

  def combine(graph_id, node1, combine_node_id, user) do
    case GraphManager.find_node_by_id(graph_id, combine_node_id) do
      nil ->
        nil

      {_g, node2} ->
        GraphManager.add_child(
          graph_id,
          [node1, node2],
          LlmInterface.gen_synthesis(node1, node2),
          "synthesis",
          user
        )
    end
  end

  def find_node(graph_id, id) do
    GraphManager.find_node_by_id(graph_id, id)
  end
end
