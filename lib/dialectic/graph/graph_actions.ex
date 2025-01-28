defmodule Dialectic.Graph.GraphActions do
  alias Dialectic.Graph.Vertex
  alias Dialectic.Responses.LlmInterface

  def create_new_node(user) do
    %Vertex{user: user, id: "NewNode"}
  end

  def answer(graph_id, node, question) do
    parents = if length(node.parents) == 0, do: [], else: [node]

    {_g, question_node} =
      GraphManager.add_child(
        graph_id,
        parents,
        question,
        "user",
        node.user
      )

    GraphManager.add_child(
      graph_id,
      [question_node],
      LlmInterface.gen_response(question, node),
      "answer",
      node.user
    )
  end

  def branch(graph_id, node) do
    GraphManager.add_child(
      graph_id,
      [node],
      LlmInterface.gen_thesis(node),
      "thesis",
      node.user
    )

    GraphManager.add_child(
      graph_id,
      [node],
      LlmInterface.gen_antithesis(node),
      "antithesis",
      node.user
    )
  end

  def combine(graph_id, node1, combine_node_id) do
    case GraphManager.find_node_by_id(graph_id, combine_node_id) do
      nil ->
        nil

      {_g, node2} ->
        GraphManager.add_child(
          graph_id,
          [node1, node2],
          LlmInterface.gen_synthesis(node1, node2),
          "synthesis",
          node1.user
        )
    end
  end

  def find_node(graph_id, id) do
    GraphManager.find_node_by_id(graph_id, id)
  end
end
