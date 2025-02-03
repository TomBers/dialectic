defmodule Dialectic.Graph.GraphActions do
  alias Dialectic.Graph.Vertex
  alias Dialectic.Responses.LlmInterface

  def create_new_node(user) do
    %Vertex{user: user, id: "NewNode", noted_by: []}
  end

  def add_noted_by({graph_id, _node, user, _pid}, node_id) do
    GraphManager.add_noted_by(graph_id, node_id, user)
  end

  def remove_noted_by({graph_id, _node, user, _pid}, node_id) do
    GraphManager.remove_noted_by(graph_id, node_id, user)
  end

  def comment({graph_id, node, user, _pid}, question) do
    GraphManager.add_child(
      graph_id,
      [node],
      fn _ -> question end,
      "user",
      user
    )
  end

  def answer({graph_id, node, user, pid}) do
    GraphManager.add_child(
      graph_id,
      [node],
      fn n -> LlmInterface.gen_response(node, n, pid) end,
      "answer",
      user
    )
  end

  def branch({graph_id, node, user, pid}) do
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

  def combine({graph_id, node1, user, pid}, combine_node_id) do
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
