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

  def toggle_graph_public({graph_id, _node, _user, _live_view_topic}) do
    GraphManager.toggle_graph_public(graph_id)
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

      node2 ->
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
    new_node = GraphManager.add_node(graph_id, vertex)
    GraphManager.find_node_by_id(graph_id, new_node.id)
  end

  def find_node(graph_id, node_id) do
    GraphManager.find_node_by_id(graph_id, node_id)
  end

  def ask_and_answer({graph_id, node, user, live_view_topic}, question_text) do
    # Otherwise, use a 'question' node for follow-up questions
    question_node =
      GraphManager.add_child(
        graph_id,
        [node],
        fn _ -> question_text end,
        "question",
        user
      )

    {nil,
     GraphManager.add_child(
       graph_id,
       [question_node],
       fn n -> LlmInterface.gen_response(question_node, n, graph_id, live_view_topic) end,
       "answer",
       user
     )}
  end

  def ask_and_answer_origin({graph_id, node, user, live_view_topic}, question_text) do
    # Fetch the latest origin vertex label safely via GraphManager (avoid direct :digraph)
    # Note: do not expose or rely on the raw digraph handle across processes

    current_origin =
      case GraphManager.vertex_label(graph_id, node.id) do
        nil -> node
        v -> v
      end

    # Append the question once to the origin content (account for encoded forms)
    decoded_question = URI.decode_www_form(to_string(question_text || ""))

    question_present? =
      is_binary(current_origin.content) and
        Enum.any?([to_string(question_text || ""), decoded_question], fn q ->
          q != "" and String.contains?(current_origin.content, q)
        end)

    updated_origin =
      if question_present? do
        current_origin
      else
        GraphManager.update_vertex(
          graph_id,
          node.id,
          if(current_origin.content && current_origin.content != "", do: "\n\n", else: "") <>
            decoded_question
        )
      end

    # If an answer child already exists for this origin, return it instead of enqueuing another
    has_answer? =
      GraphManager.has_child_with_class(graph_id, updated_origin.id, "answer")

    if has_answer? do
      # Return the first existing answer node
      answer_id =
        GraphManager.out_neighbours(graph_id, updated_origin.id)
        |> Enum.find(fn cid ->
          case GraphManager.vertex_label(graph_id, cid) do
            %{} = v -> Map.get(v, :class) == "answer"
            _ -> false
          end
        end)

      {nil, GraphManager.find_node_by_id(graph_id, answer_id)}
    else
      # Create the answer node immediately so GraphLive can show progress after redirect.
      # The worker streams content into this node via PubSub updates.
      answer_node =
        GraphManager.add_child(
          graph_id,
          [updated_origin],
          fn _ -> "" end,
          "answer",
          user
        )

      # Kick off the AI answer generation (streaming) targeting the new answer node.
      LlmInterface.gen_response(updated_origin, answer_node, graph_id, live_view_topic)

      {nil, answer_node}
    end
  end

  def regenerate_node({graph_id, _node, user, live_view_topic}, stuck_node_id) do
    case GraphManager.find_node_by_id(graph_id, stuck_node_id) do
      nil ->
        {:error, "Node not found"}

      stuck_node ->
        parents = stuck_node.parents
        children = stuck_node.children

        {valid?, error_msg} =
          case stuck_node.class do
            c when c in ["thesis", "antithesis", "deepdive", "ideas", "answer"] ->
              if List.first(parents) != nil,
                do: {true, nil},
                else: {false, "Missing parent node"}

            "synthesis" ->
              if length(parents) >= 2,
                do: {true, nil},
                else: {false, "Need at least 2 parent nodes for synthesis"}

            other ->
              {false, "Regeneration is not available for node type '#{other}'."}
          end

        if valid? do
          # Delete the stuck node immediately so we can replace it
          GraphManager.delete_node(graph_id, stuck_node_id)

          new_node =
            case stuck_node.class do
              "thesis" ->
                parent = List.first(parents)

                GraphManager.add_child(
                  graph_id,
                  [parent],
                  fn n -> LlmInterface.gen_thesis(parent, n, graph_id, live_view_topic) end,
                  "thesis",
                  user
                )

              "antithesis" ->
                parent = List.first(parents)

                GraphManager.add_child(
                  graph_id,
                  [parent],
                  fn n -> LlmInterface.gen_antithesis(parent, n, graph_id, live_view_topic) end,
                  "antithesis",
                  user
                )

              "deepdive" ->
                parent = List.first(parents)
                deepdive({graph_id, parent, user, live_view_topic})

              "ideas" ->
                parent = List.first(parents)
                related_ideas({graph_id, parent, user, live_view_topic})

              "answer" ->
                parent = List.first(parents)
                answer({graph_id, parent, user, live_view_topic})

              "synthesis" ->
                [p1, p2 | _] = parents
                combine({graph_id, p1, user, live_view_topic}, p2.id)

              _ ->
                nil
            end

          if new_node do
            if children != [] do
              Enum.each(children, fn child ->
                GraphManager.add_edges(graph_id, child, [new_node])
              end)

              GraphManager.save_graph(graph_id)
            end

            {:ok, new_node}
          else
            {:error, "Failed to create replacement node"}
          end
        else
          {:error, error_msg}
        end
    end
  end
end
