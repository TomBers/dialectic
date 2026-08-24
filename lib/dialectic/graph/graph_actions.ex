defmodule Dialectic.Graph.GraphActions do
  @moduledoc """
  High-level actions for manipulating thought graphs.

  This module provides the main interface for creating, modifying, and applying
  critical thinking tools to nodes in a dialectic graph.
  """

  alias Dialectic.Graph.Vertex
  alias Dialectic.Responses.LlmInterface

  # Configuration for critical thinking tools
  # Each tool has a node class and corresponding LlmInterface function
  @thinking_tools [
    {:clarify, "clarify", :gen_clarify, "Clarify the meaning or intent of a node's content"},
    {:assumptions, "assumptions", :gen_assumptions,
     "Identify underlying assumptions in a node's argument"},
    {:counterexample, "counterexample", :gen_counterexample,
     "Find counterexamples that challenge a node's claims"},
    {:implications, "implications", :gen_implications,
     "Explore the logical implications and consequences"},
    {:blind_spots, "blind_spots", :gen_blind_spots,
     "Identify potential blind spots or overlooked perspectives"},
    {:says_who, "says_who", :gen_says_who, "Question the source and evidence behind claims"},
    {:who_disagrees, "who_disagrees", :gen_who_disagrees, "Explore who might disagree and why"},
    {:steel_man, "steel_man", :gen_steel_man,
     "Build the strongest possible version of the argument"},
    {:what_if, "what_if", :gen_what_if, "Explore what-if scenarios and alternative conditions"}
  ]

  @doc """
  Creates a new empty node with a unique ID.

  ## Parameters
    - user: The user creating the node

  ## Returns
    A new Vertex struct
  """
  def create_new_node(user) do
    unique_id = "NewNode-" <> Integer.to_string(System.unique_integer([:positive]))
    %Vertex{user: user, id: unique_id, noted_by: []}
  end

  @doc """
  Moves a node in a specific direction within the graph.

  ## Parameters
    - context: Tuple of {graph_id, node, user, live_view_topic}
    - direction: The direction to move the node
  """
  def move({graph_id, node, _user, _live_view_topic}, direction) do
    GraphManager.move(graph_id, node, direction)
  end

  @doc """
  Deletes a node from the graph.

  ## Parameters
    - context: Tuple of {graph_id, node, user, live_view_topic}
    - node_id: ID of the node to delete
  """
  def delete_node({graph_id, _node, _user, _live_view_topic}, node_id) do
    GraphManager.delete_node(graph_id, node_id)
  end

  @doc """
  Changes the noted_by field of a node using a transformation function.

  ## Parameters
    - context: Tuple of {graph_id, node, user, live_view_topic}
    - node_id: ID of the node to update
    - change_fn: Function to transform the noted_by list
  """
  def change_noted_by({graph_id, _node, user, _live_view_topic}, node_id, change_fn) do
    GraphManager.change_noted_by(graph_id, node_id, user, change_fn)
  end

  @doc """
  Toggles the locked state of a graph.
  """
  def toggle_graph_locked({graph_id, _node, _user, _live_view_topic}) do
    GraphManager.toggle_graph_locked(graph_id)
  end

  @doc """
  Toggles the public visibility state of a graph.
  """
  def toggle_graph_public({graph_id, _node, _user, _live_view_topic}) do
    GraphManager.toggle_graph_public(graph_id)
  end

  @doc """
  Adds a user comment as a child node.

  ## Parameters
    - context: Tuple of {graph_id, node, user, live_view_topic}
    - question: The comment text
    - prefix: Optional prefix to prepend to the comment
  """
  def comment({graph_id, node, user, _live_view_topic}, question, prefix \\ "", opts \\ []) do
    GraphManager.add_child(
      graph_id,
      [node],
      fn _ -> prefix <> question end,
      "user",
      user,
      opts
    )
  end

  @doc """
  Generates an AI answer to a node.

  ## Parameters
    - context: Tuple of {graph_id, node, user, live_view_topic}

  ## Returns
    The newly created answer node
  """
  def answer({graph_id, node, user, live_view_topic}) do
    GraphManager.add_child(
      graph_id,
      [node],
      fn n -> LlmInterface.gen_response(node, n, graph_id, live_view_topic) end,
      "answer",
      user
    )
  end

  @doc """
  Generates an AI response to a specific text selection.

  ## Parameters
    - context: Tuple of {graph_id, node, user, live_view_topic}
    - selection: The selected text
    - type: The type of response node to create
  """
  def answer_selection({graph_id, node, user, live_view_topic}, selection, type) do
    selection = normalize_source_text(selection)

    GraphManager.add_child(
      graph_id,
      [node],
      fn n ->
        LlmInterface.gen_selection_response(node, n, graph_id, selection || "", live_view_topic)
      end,
      type,
      user,
      source_text_opts(selection)
    )
  end

  @doc """
  Creates thesis and antithesis branches from a node.

  ## Parameters
    - context: Tuple of {graph_id, node, user, live_view_topic}
    - opts: Optional keyword list with :content_override

  ## Returns
    The exact thesis and antithesis nodes created by this call, in that order
  """
  def branch({graph_id, node, user, live_view_topic}, opts \\ []) do
    content_override = opts |> Keyword.get(:content_override) |> normalize_source_text()

    child_opts = generation_opts(source_text_opts(content_override), opts)

    thesis_node =
      GraphManager.add_child(
        graph_id,
        [node],
        fn n ->
          LlmInterface.gen_thesis(node, n, graph_id, live_view_topic, content_override)
        end,
        "thesis",
        user,
        child_opts
      )

    antithesis_node =
      GraphManager.add_child(
        graph_id,
        [node],
        fn n ->
          LlmInterface.gen_antithesis(node, n, graph_id, live_view_topic, content_override)
        end,
        "antithesis",
        user,
        child_opts
      )

    nodes = [thesis_node, antithesis_node]

    if Keyword.get(opts, :await_generation, false) && Enum.any?(nodes, &is_nil/1) do
      nodes
      |> Enum.filter(&is_map/1)
      |> Enum.each(&GraphManager.delete_node(graph_id, &1.id))

      GraphManager.save_graph(graph_id)
      []
    else
      nodes
    end
  end

  @doc """
  Combines two nodes into a synthesis node.

  ## Parameters
    - context: Tuple of {graph_id, node1, user, live_view_topic}
    - combine_node_id: ID of the second node to combine

  ## Returns
    The synthesis node, or nil if the second node doesn't exist
  """
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

  @doc """
  Generates related ideas for a node.

  ## Parameters
    - context: Tuple of {graph_id, node, user, live_view_topic}
    - opts: Optional keyword list with :content_override

  ## Returns
    The newly created ideas node
  """
  def related_ideas({graph_id, node, user, live_view_topic}, opts \\ []) do
    content_override = opts |> Keyword.get(:content_override) |> normalize_source_text()

    GraphManager.add_child(
      graph_id,
      [node],
      fn n ->
        LlmInterface.gen_related_ideas(node, n, graph_id, live_view_topic, content_override)
      end,
      "ideas",
      user,
      generation_opts(source_text_opts(content_override), opts)
    )
  end

  # Critical Thinking Tools
  # The following functions are generated programmatically from @thinking_tools

  @doc """
  Generic function to apply a thinking tool to a node.

  This is the core abstraction that all thinking tool functions use.
  It applies a given thinking tool by calling the appropriate LLM interface
  function and creating a child node with the result.

  ## Parameters
    - tool_key: Atom key from @thinking_tools (e.g., :clarify, :assumptions)
    - context: Tuple of {graph_id, node, user, live_view_topic}
    - opts: Optional keyword list with :content_override

  ## Returns
    The newly created tool node, or nil if the tool key is unknown.

  ## Examples

      apply_thinking_tool(:clarify, {graph_id, node, user, topic})
      apply_thinking_tool(:assumptions, {graph_id, node, user, topic}, content_override: "text")
  """
  def apply_thinking_tool(tool_key, {graph_id, node, user, live_view_topic}, opts \\ []) do
    case Enum.find(@thinking_tools, fn {key, _class, _llm_fn, _doc} -> key == tool_key end) do
      nil ->
        nil

      {^tool_key, class, llm_fn, _doc} ->
        content_override = opts |> Keyword.get(:content_override) |> normalize_source_text()

        add_child_opts = generation_opts(source_text_opts(content_override), opts)

        GraphManager.add_child(
          graph_id,
          [node],
          fn n ->
            apply(LlmInterface, llm_fn, [
              node,
              n,
              graph_id,
              live_view_topic,
              content_override
            ])
          end,
          class,
          user,
          add_child_opts
        )
    end
  end

  @doc """
  Generic function to apply a thinking tool to selected text.

  This wraps apply_thinking_tool/3 and additionally stores the selected
  text in the node's source_text field for context.

  ## Parameters
    - tool_key: Atom key from @thinking_tools
    - context: Tuple of {graph_id, node, user, live_view_topic}
    - selected_text: The text selection to analyze

  ## Returns
    The newly created tool node with source_text metadata, or nil if creation failed
  """
  def apply_thinking_tool_to_text(
        tool_key,
        {graph_id, node, user, live_view_topic},
        selected_text
      ) do
    apply_thinking_tool(
      tool_key,
      {graph_id, node, user, live_view_topic},
      content_override: selected_text
    )
  end

  # Generate public API functions for each thinking tool
  # This creates functions like clarify/2, assumptions/2, etc.
  for {tool_name, class, _llm_fn, doc} <- @thinking_tools do
    @doc """
    #{doc}.

    ## Parameters
      - context: Tuple of {graph_id, node, user, live_view_topic}
      - opts: Optional keyword list with :content_override

    ## Returns
      The newly created #{class} node
    """
    def unquote(tool_name)(context, opts \\ []) do
      apply_thinking_tool(unquote(tool_name), context, opts)
    end

    text_fn_name = :"#{tool_name}_text"

    @doc """
    #{doc} for selected text within a node.

    Creates a #{class} node with context about the specific text being analyzed.

    ## Parameters
      - context: Tuple of {graph_id, node, user, live_view_topic}
      - selected_text: The text selection to analyze

    ## Returns
      The newly created #{class} node with source_text metadata, or nil
    """
    def unquote(text_fn_name)(context, selected_text) do
      apply_thinking_tool_to_text(unquote(tool_name), context, selected_text)
    end
  end

  @doc """
  Creates a new stream (origin node) in the graph.

  ## Parameters
    - context: Tuple of {graph_id, node, user, live_view_topic}
    - content: The initial content for the stream
    - opts: Optional keyword list with :group_id

  ## Returns
    The newly created origin node
  """
  def new_stream({graph_id, _node, user, _live_view_topic}, content, opts) do
    parent_group_id = Keyword.get(opts, :group_id)
    vertex = %Vertex{content: content || "", class: "origin", user: user, parent: parent_group_id}
    new_node = GraphManager.add_node(graph_id, vertex)
    GraphManager.find_node_by_id(graph_id, new_node.id)
  end

  @doc """
  Finds a node by its ID.

  ## Parameters
    - graph_id: The graph ID
    - node_id: The node ID to find

  ## Returns
    The node if found, nil otherwise
  """
  def find_node(graph_id, node_id) do
    GraphManager.find_node_by_id(graph_id, node_id)
  end

  @doc """
  Asks a question and generates an answer as child nodes.

  Creates a question node followed by an answer node.

  ## Parameters
    - context: Tuple of {graph_id, node, user, live_view_topic}
    - question_text: The question to ask
    - opts: Optional keyword list with :minimal_context (default false)

  ## Returns
    Tuple of {nil, answer_node}
  """
  def ask_and_answer({graph_id, node, user, live_view_topic}, question_text, opts \\ []) do
    minimal_context = Keyword.get(opts, :minimal_context, false)
    guided_learning = Keyword.get(opts, :guided_learning, false)
    source_text = opts |> Keyword.get(:source_text) |> normalize_source_text()

    {question_prompt_kind, answer_prompt_kind} =
      cond do
        guided_learning ->
          {"guided_learning_plan_question", "guided_learning_plan"}

        minimal_context ->
          {"selection_explain_question", "selection_explain"}

        true ->
          {"question", "answer"}
      end

    question_opts = source_text_opts(source_text, question_prompt_kind)
    answer_opts = generation_opts(source_text_opts(source_text, answer_prompt_kind), opts)

    # Use a 'question' node for follow-up questions
    question_node =
      GraphManager.add_child(
        graph_id,
        [node],
        fn _ -> question_text end,
        "question",
        user,
        Keyword.put(question_opts, :save, false)
      )

    answer_node =
      GraphManager.add_child(
        graph_id,
        [question_node],
        fn n ->
          cond do
            guided_learning ->
              LlmInterface.gen_guided_learning_plan(question_node, n, graph_id, live_view_topic)

            minimal_context ->
              LlmInterface.gen_response_minimal_context(
                question_node,
                n,
                graph_id,
                live_view_topic
              )

            true ->
              LlmInterface.gen_response(question_node, n, graph_id, live_view_topic)
          end
        end,
        if(guided_learning, do: "learning_plan", else: "answer"),
        user,
        Keyword.put(answer_opts, :cleanup_on_failure, [question_node.id])
      )

    {nil, answer_node}
  end

  @doc """
  Ask a question about a specific text selection.

  Creates a question node with the user's question and stores the selected
  text as context, then generates an answer with minimal context focused
  on the selection.

  ## Parameters
    - context: Tuple of {graph_id, node, user, live_view_topic}
    - question_text: The question to ask
    - selected_text: The text selection to ask about

  ## Returns
    Tuple of {nil, answer_node}
  """
  def ask_about_selection(
        {graph_id, node, user, live_view_topic},
        question_text,
        selected_text
      ) do
    question_opts = source_text_opts(selected_text, "selection_question_input")
    answer_opts = source_text_opts(selected_text, "selection_question")

    # Create question node with both the question and the selected text context
    question_node =
      GraphManager.add_child(
        graph_id,
        [node],
        fn _ -> question_text end,
        "question",
        user,
        question_opts
      )

    # Generate answer with minimal context (focused on the selection)
    answer_node =
      GraphManager.add_child(
        graph_id,
        [question_node],
        fn n ->
          LlmInterface.gen_response_minimal_context(question_node, n, graph_id, live_view_topic)
        end,
        "answer",
        user,
        answer_opts
      )

    {nil, answer_node}
  end

  defp generation_opts(child_opts, opts) do
    Keyword.merge(child_opts, Keyword.take(opts, [:await_generation]))
  end

  defp source_text_opts(source_text, prompt_kind \\ nil) do
    fields =
      case normalize_source_text(source_text) do
        nil -> %{}
        text -> %{source_text: text}
      end

    fields =
      if is_binary(prompt_kind), do: Map.put(fields, :prompt_kind, prompt_kind), else: fields

    if map_size(fields) == 0, do: [], else: [fields: fields]
  end

  defp normalize_source_text(source_text) when is_binary(source_text) do
    source_text
    |> String.trim()
    |> case do
      "" -> nil
      text -> text
    end
  end

  defp normalize_source_text(_source_text), do: nil

  defp node_source_text(%{} = node) do
    node
    |> Map.get(:source_text)
    |> normalize_source_text()
  end

  defp node_source_text(_node), do: nil

  # Private helper to validate whether a node type can be regenerated
  defp validate_regeneration(class, parents) do
    # Get all thinking tool classes
    thinking_tool_classes =
      Enum.map(@thinking_tools, fn {_key, class, _llm_fn, _doc} -> class end)

    cond do
      class == "synthesis" ->
        if length(parents) >= 2,
          do: {true, nil},
          else: {false, "Need at least 2 parent nodes for synthesis"}

      class in ["thesis", "antithesis", "ideas", "answer", "learning_plan", "explain"] or
          class in thinking_tool_classes ->
        if List.first(parents) != nil,
          do: {true, nil},
          else: {false, "Missing parent node"}

      true ->
        {false, "Regeneration is not available for node type '#{class}'."}
    end
  end

  @doc """
  Regenerates a node by deleting it and recreating it with the same type.

  This is useful when a node's generation fails or produces unsatisfactory results.
  The function validates that the node type supports regeneration and that all
  required parent nodes exist.

  ## Parameters
    - context: Tuple of {graph_id, node, user, live_view_topic}
    - stuck_node_id: ID of the node to regenerate

  ## Returns
    - {:ok, new_node} on success
    - {:error, message} on failure
  """
  def regenerate_node({graph_id, _node, user, live_view_topic}, stuck_node_id) do
    case GraphManager.find_node_by_id(graph_id, stuck_node_id) do
      nil ->
        {:error, "Node not found"}

      %{deleted: true} ->
        {:error, "Node is no longer available"}

      stuck_node ->
        parents = stuck_node.parents
        children = stuck_node.children

        {valid?, error_msg} = validate_regeneration(stuck_node.class, parents)

        if valid? do
          # Delete the stuck node immediately so we can replace it
          GraphManager.delete_node(graph_id, stuck_node_id)

          new_node = regenerate_by_type(stuck_node, graph_id, parents, user, live_view_topic)

          if new_node do
            # Reconnect any children that were attached to the old node
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

  # Private helper for regenerate_node
  # Dispatches to the appropriate function based on node type
  defp regenerate_by_type(stuck_node, graph_id, parents, user, live_view_topic) do
    parent = List.first(parents)
    prompt_kind = Map.get(stuck_node, :prompt_kind)

    source_text =
      node_source_text(stuck_node) ||
        if(is_nil(prompt_kind), do: node_source_text(parent), else: nil)

    source_text_opts = source_text_opts(source_text, prompt_kind)

    if initial_answer?(stuck_node, parent, parents) do
      GraphManager.add_child(
        graph_id,
        [parent],
        fn n -> LlmInterface.gen_initial_response(parent, n, graph_id, live_view_topic) end,
        "answer",
        user,
        source_text_opts(source_text, "initial_explainer")
      )
    else
      regenerate_by_class(
        stuck_node.class,
        graph_id,
        parent,
        parents,
        user,
        live_view_topic,
        source_text,
        source_text_opts
      )
    end
  end

  defp initial_answer?(stuck_node, parent, parents) do
    stuck_node.class == "answer" and
      (Map.get(stuck_node, :prompt_kind) == "initial_explainer" or
         (is_nil(Map.get(stuck_node, :prompt_kind)) and length(parents) == 1 and
            Map.get(parent, :class) == "origin" and Map.get(parent, :id) == "1"))
  end

  defp regenerate_by_class(
         class,
         graph_id,
         parent,
         parents,
         user,
         live_view_topic,
         source_text,
         source_text_opts
       ) do
    case class do
      "thesis" ->
        GraphManager.add_child(
          graph_id,
          [parent],
          fn n -> LlmInterface.gen_thesis(parent, n, graph_id, live_view_topic, source_text) end,
          "thesis",
          user,
          source_text_opts
        )

      "antithesis" ->
        GraphManager.add_child(
          graph_id,
          [parent],
          fn n ->
            LlmInterface.gen_antithesis(parent, n, graph_id, live_view_topic, source_text)
          end,
          "antithesis",
          user,
          source_text_opts
        )

      "ideas" ->
        related_ideas({graph_id, parent, user, live_view_topic}, content_override: source_text)

      "learning_plan" ->
        GraphManager.add_child(
          graph_id,
          [parent],
          fn n -> LlmInterface.gen_guided_learning_plan(parent, n, graph_id, live_view_topic) end,
          "learning_plan",
          user,
          source_text_opts
        )

      "answer" ->
        cond do
          source_text ->
            GraphManager.add_child(
              graph_id,
              [parent],
              fn n ->
                LlmInterface.gen_response_minimal_context(parent, n, graph_id, live_view_topic)
              end,
              "answer",
              user,
              source_text_opts
            )

          true ->
            answer({graph_id, parent, user, live_view_topic})
        end

      "explain" ->
        GraphManager.add_child(
          graph_id,
          [parent],
          fn n ->
            LlmInterface.gen_selection_response(
              parent,
              n,
              graph_id,
              source_text || "",
              live_view_topic
            )
          end,
          "explain",
          user,
          source_text_opts
        )

      "synthesis" ->
        [p1, p2 | _] = parents
        combine({graph_id, p1, user, live_view_topic}, p2.id)

      # Handle all thinking tools dynamically
      class ->
        # Find the tool key that matches this class
        tool_key =
          Enum.find_value(@thinking_tools, fn {key, tool_class, _llm_fn, _doc} ->
            if tool_class == class, do: key
          end)

        if tool_key do
          apply_thinking_tool(tool_key, {graph_id, parent, user, live_view_topic},
            content_override: source_text
          )
        end
    end
  end
end
