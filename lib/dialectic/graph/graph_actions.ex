defmodule Dialectic.Graph.GraphActions do
  alias Dialectic.Graph.Vertex
  alias Dialectic.Responses.LlmInterface

  def create_new_node(user) do
    %Vertex{user: user, id: "NewNode", noted_by: []}
  end

  def move({graph_id, node, _user, _live_view_topic}, direction) do
    GraphManager.move(graph_id, node, direction)
  end

  def delete_node({graph_id, _node, _user, _live_view_topic}, node_id) do
    GraphManager.delete_node(graph_id, node_id)
  end

  def change_noted_by({graph_id, _node, user, _live_view_topic}, node_id, change_fn) do
    GraphManager.change_noted_by(graph_id, node_id, user, change_fn)
  end

  def toggle_graph_locked({graph_id, _node, _user, _live_view_topic}) do
    GraphManager.toggle_graph_locked(graph_id)
  end

  def comment({graph_id, node, user, _live_view_topic}, question, prefix \\ "") do
    GraphManager.add_child(
      graph_id,
      [node],
      fn _ -> prefix <> question end,
      "user",
      user
    )
  end

  def answer({graph_id, node, user, live_view_topic}) do
    GraphManager.add_child(
      graph_id,
      [node],
      fn n -> LlmInterface.gen_response(node, n, graph_id, live_view_topic) end,
      "answer",
      user
    )
  end

  def answer_selection({graph_id, node, user, live_view_topic}, selection, type) do
    GraphManager.add_child(
      graph_id,
      [node],
      fn n ->
        LlmInterface.gen_selection_response(node, n, graph_id, selection, live_view_topic)
      end,
      type,
      user
    )
  end

  def branch({graph_id, node, user, live_view_topic}) do
    GraphManager.add_child(
      graph_id,
      [node],
      fn n -> LlmInterface.gen_thesis(node, n, graph_id, live_view_topic) end,
      "thesis",
      user
    )

    GraphManager.add_child(
      graph_id,
      [node],
      fn n -> LlmInterface.gen_antithesis(node, n, graph_id, live_view_topic) end,
      "antithesis",
      user
    )
  end

  def combine({graph_id, node1, user, live_view_topic}, combine_node_id) do
    case GraphManager.find_node_by_id(graph_id, combine_node_id) do
      nil ->
        nil

      {_g, node2} ->
        GraphManager.add_child(
          graph_id,
          [node1, node2],
          fn n -> LlmInterface.gen_synthesis(node1, node2, n, graph_id, live_view_topic) end,
          "synthesis",
          user
        )
    end
  end

  def related_ideas({graph_id, node, user, live_view_topic}) do
    GraphManager.add_child(
      graph_id,
      [node],
      fn n -> LlmInterface.gen_related_ideas(node, n, graph_id, live_view_topic) end,
      "ideas",
      user
    )
  end

  def find_node(graph_id, id) do
    GraphManager.find_node_by_id(graph_id, id)
  end
end
