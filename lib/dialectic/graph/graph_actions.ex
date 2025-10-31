defmodule Dialectic.Graph.GraphActions do
  alias Dialectic.Graph.Vertex
  alias Dialectic.Responses.LlmInterface

  def create_new_node(user) do
    unique_id = "NewNode-" <> Integer.to_string(System.unique_integer([:positive]))
    %Vertex{user: user, id: unique_id, noted_by: []}
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

  def answer({graph_id, node, user, live_view_topic}, opts \\ []) do
    GraphManager.add_child(
      graph_id,
      [node],
      fn n -> LlmInterface.gen_response(node, n, graph_id, live_view_topic, opts) end,
      "answer",
      user
    )
  end

  def answer_selection({graph_id, node, user, live_view_topic}, selection, type, opts \\ []) do
    GraphManager.add_child(
      graph_id,
      [node],
      fn n ->
        LlmInterface.gen_selection_response(node, n, graph_id, selection, live_view_topic, opts)
      end,
      type,
      user
    )
  end

  def branch({graph_id, node, user, live_view_topic}, opts \\ []) do
    GraphManager.add_child(
      graph_id,
      [node],
      fn n -> LlmInterface.gen_thesis(node, n, graph_id, live_view_topic, opts) end,
      "thesis",
      user
    )

    GraphManager.add_child(
      graph_id,
      [node],
      fn n -> LlmInterface.gen_antithesis(node, n, graph_id, live_view_topic, opts) end,
      "antithesis",
      user
    )
  end

  def combine({graph_id, node1, user, live_view_topic}, combine_node_id, opts \\ []) do
    case GraphManager.find_node_by_id(graph_id, combine_node_id) do
      nil ->
        nil

      {_g, node2} ->
        GraphManager.add_child(
          graph_id,
          [node1, node2],
          fn n ->
            LlmInterface.gen_synthesis(node1, node2, n, graph_id, live_view_topic, opts)
          end,
          "synthesis",
          user
        )
    end
  end

  def related_ideas({graph_id, node, user, live_view_topic}, opts \\ []) do
    GraphManager.add_child(
      graph_id,
      [node],
      fn n -> LlmInterface.gen_related_ideas(node, n, graph_id, live_view_topic, opts) end,
      "ideas",
      user
    )
  end

  def deepdive({graph_id, node, user, live_view_topic}, opts \\ []) do
    GraphManager.add_child(
      graph_id,
      [node],
      fn n -> LlmInterface.gen_deepdive(node, n, graph_id, live_view_topic, opts) end,
      "deepdive",
      user
    )
  end

  def new_stream({graph_id, _node, user, _live_view_topic}, content, opts) do
    parent_group_id = Keyword.get(opts, :group_id)
    vertex = %Vertex{content: content || "", class: "origin", user: user, parent: parent_group_id}
    node = GraphManager.add_node(graph_id, vertex)
    GraphManager.find_node_by_id(graph_id, node.id)
  end

  def find_node(graph_id, id) do
    GraphManager.find_node_by_id(graph_id, id)
  end

  def ask_and_answer({graph_id, node, user, live_view_topic}, question_text, opts \\ []) do
    # 1) Create a visually distinct 'question' node under the selected node (no async update)
    {_graph1, question_node} =
      GraphManager.add_child(
        graph_id,
        [node],
        fn _ -> :ok end,
        "question",
        user
      )

    # 2) Set the question content synchronously to avoid races
    updated_question =
      GraphManager.update_vertex(graph_id, question_node.id, question_text)

    # 3) Create an AI 'answer' node as a child of the question node, using the updated question
    GraphManager.add_child(
      graph_id,
      [updated_question],
      fn n -> LlmInterface.gen_response(updated_question, n, graph_id, live_view_topic, opts) end,
      "answer",
      user
    )
  end
end
