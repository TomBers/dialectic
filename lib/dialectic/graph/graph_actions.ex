defmodule Dialectic.Graph.GraphActions do
  alias Dialectic.Graph.Vertex
  alias Dialectic.Responses.LlmInterface

  def create_new_node(user) do
    %Vertex{user: user, id: "NewNode", noted_by: []}
  end

  def move({graph_id, node, _user}, direction) do
    GraphManager.move(graph_id, node, direction)
  end

  def delete_node({graph_id, _node, _user}, node_id) do
    GraphManager.delete_node(graph_id, node_id)
  end

  def change_noted_by({graph_id, _node, user}, node_id, change_fn) do
    GraphManager.change_noted_by(graph_id, node_id, user, change_fn)
  end

  def toggle_graph_locked({graph_id, _node, _user}) do
    GraphManager.toggle_graph_locked(graph_id)
  end

  def comment({graph_id, node, user}, question, prefix \\ "") do
    GraphManager.add_child(
      graph_id,
      [node],
      fn _ -> prefix <> question end,
      "user",
      user
    )
  end

  def answer({graph_id, node, user}) do
    GraphManager.add_child(
      graph_id,
      [node],
      fn n -> LlmInterface.gen_response(node, n, graph_id) end,
      "answer",
      user
    )
  end

  def answer_selection({graph_id, node, user}, selection) do
    GraphManager.add_child(
      graph_id,
      [node],
      fn n -> LlmInterface.gen_selection_response(node, n, graph_id, selection) end,
      "answer",
      user
    )
  end

  def branch({graph_id, node, user}) do
    GraphManager.add_child(
      graph_id,
      [node],
      fn n -> LlmInterface.gen_thesis(node, n, graph_id) end,
      "thesis",
      user
    )

    GraphManager.add_child(
      graph_id,
      [node],
      fn n -> LlmInterface.gen_antithesis(node, n, graph_id) end,
      "antithesis",
      user
    )
  end

  def branch_list_items({graph_id, node, user}, list_items) do
    # Create a child node for each list item
    Enum.reduce(list_items, {nil, nil}, fn item, _acc ->
      GraphManager.add_child(
        graph_id,
        [node],
        fn _ -> item end,
        "user",
        user
      )
    end)
  end

  def combine({graph_id, node1, user}, combine_node_id) do
    case GraphManager.find_node_by_id(graph_id, combine_node_id) do
      nil ->
        nil

      {_g, node2} ->
        GraphManager.add_child(
          graph_id,
          [node1, node2],
          fn n -> LlmInterface.gen_synthesis(node1, node2, n, graph_id) end,
          "synthesis",
          user
        )
    end
  end

  def find_node(graph_id, id) do
    GraphManager.find_node_by_id(graph_id, id)
  end
end
