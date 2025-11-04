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

  def deepdive({graph_id, node, user, live_view_topic}) do
    GraphManager.add_child(
      graph_id,
      [node],
      fn n -> LlmInterface.gen_deepdive(node, n, graph_id, live_view_topic) end,
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

  def ask_and_answer({graph_id, node, user, live_view_topic}, question_text) do
    # If we're at the graph root (original context), use an 'origin' node for the first question
    if Map.get(node, :class) == "origin" and Map.get(node, :id) == "1" do
      ask_and_answer_origin({graph_id, node, user, live_view_topic}, question_text)
    else
      # Otherwise, use a 'question' node for follow-up questions
      {_graph1, question_node} =
        GraphManager.add_child(
          graph_id,
          [node],
          fn _ -> :ok end,
          "question",
          user
        )

      updated_question =
        GraphManager.update_vertex(graph_id, question_node.id, question_text)

      GraphManager.add_child(
        graph_id,
        [updated_question],
        fn n -> LlmInterface.gen_response(updated_question, n, graph_id, live_view_topic) end,
        "answer",
        user
      )
    end
  end

  def ask_and_answer_origin({graph_id, node, user, live_view_topic}, question_text) do
    # Fetch the latest origin vertex to avoid stale content
    {_gs, g} = GraphManager.get_graph(graph_id)

    current_origin =
      case :digraph.vertex(g, node.id) do
        {id, v} when id == node.id -> v
        _ -> node
      end

    # Append the question once to the origin content
    updated_origin =
      if is_binary(current_origin.content) and
           String.contains?(current_origin.content, question_text) do
        current_origin
      else
        GraphManager.update_vertex(
          graph_id,
          node.id,
          if(current_origin.content && current_origin.content != "", do: "\n\n", else: "") <>
            question_text
        )
      end

    # If an answer child already exists for this origin, return it instead of enqueuing another
    has_answer? =
      try do
        children = :digraph.out_neighbours(g, updated_origin.id)

        Enum.any?(children, fn cid ->
          case :digraph.vertex(g, cid) do
            {^cid, v} when is_map(v) -> Map.get(v, :class) == "answer"
            _ -> false
          end
        end)
      rescue
        _ -> false
      end

    if has_answer? do
      # Return the first existing answer node
      answer_id =
        :digraph.out_neighbours(g, updated_origin.id)
        |> Enum.find(fn cid ->
          case :digraph.vertex(g, cid) do
            {^cid, v} when is_map(v) -> Map.get(v, :class) == "answer"
            _ -> false
          end
        end)

      GraphManager.find_node_by_id(graph_id, answer_id)
    else
      # Generate the AI answer as a child of the updated origin node
      GraphManager.add_child(
        graph_id,
        [updated_origin],
        fn n -> LlmInterface.gen_response(updated_origin, n, graph_id, live_view_topic) end,
        "answer",
        user
      )
    end
  end
end
