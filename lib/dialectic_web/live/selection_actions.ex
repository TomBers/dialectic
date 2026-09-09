defmodule DialecticWeb.SelectionActions do
  alias Dialectic.Graph.GraphActions
  alias Dialectic.Highlights
  alias DialecticWeb.GraphHelpers

  @thinking_tools ~w(clarify assumptions counterexample implications blind_spots says_who who_disagrees steel_man what_if)a
  @actions [:highlight_only, :comment, :ask_question, :explain, :pros_cons, :related_ideas] ++
             @thinking_tools

  def perform(socket, params) do
    {action, text, node_id, offsets, existing_highlight, extra} =
      GraphHelpers.unpack_selection_action(params)

    with :ok <- GraphHelpers.validate_selection_target(socket, action, node_id),
         :ok <- validate_input(action, text, extra) do
      parent = GraphActions.find_node(socket.assigns.graph_id, node_id)
      context = GraphHelpers.graph_action_params(socket, parent)
      highlight = existing_highlight || create_highlight(socket, node_id, offsets, text)
      perform_action(action, context, text, extra, highlight)
    end
  end

  defp validate_input(action, text, extra) do
    cond do
      action not in @actions ->
        {:error, "Choose an available passage action."}

      GraphHelpers.inquiry_content(text) == "" ->
        {:error, "Please select some text"}

      action == :comment && GraphHelpers.inquiry_content(extra[:comment]) == "" ->
        {:error, "Write a comment or question first."}

      action == :ask_question && GraphHelpers.inquiry_content(extra[:question]) == "" ->
        {:error, "Write a comment or question first."}

      true ->
        :ok
    end
  end

  defp perform_action(:highlight_only, _context, _text, _extra, nil),
    do: {:error, "Could not save highlight. Please try again."}

  defp perform_action(:highlight_only, _context, _text, _extra, _highlight),
    do: {:ok, %{kind: :highlight}}

  defp perform_action(:comment, context, text, extra, highlight) do
    comment = GraphHelpers.inquiry_content(extra.comment)

    node =
      GraphActions.comment(context, "#{comment}\n\nRegarding: \"#{text}\"", "",
        fields: %{source_text: text}
      )

    if node do
      link(highlight, node, "comment")
      {:ok, %{kind: :comment, node: node}}
    else
      {:error, "Your thought could not be saved. Please try again."}
    end
  end

  defp perform_action(:ask_question, context, text, extra, highlight) do
    {_, node} =
      GraphActions.ask_about_selection(
        context,
        GraphHelpers.inquiry_content(extra.question),
        text
      )

    link(highlight, node, "question")
    generation([node], "selection_question", "Answering your question about #{quoted(text)}")
  end

  defp perform_action(:explain, context, text, _extra, highlight) do
    {_, node} =
      GraphActions.ask_and_answer(context, "Please explain: #{text}",
        minimal_context: true,
        source_text: text
      )

    link(highlight, node, "explain")
    generation([node], "explain", "Explaining #{quoted(text)}")
  end

  defp perform_action(:pros_cons, {_, parent, _, _} = context, text, _extra, highlight) do
    nodes =
      GraphActions.branch(context, content_override: text)
      |> Enum.filter(&is_map/1)
      |> Enum.sort_by(fn node -> if node.class == "thesis", do: 0, else: 1 end)

    Enum.each(nodes, &link(highlight, &1, if(&1.class == "thesis", do: "pro", else: "con")))
    generation(nodes, "branch", "Testing both sides of #{quoted(text)}", parent.id)
  end

  defp perform_action(:related_ideas, context, text, _extra, highlight) do
    node = GraphActions.related_ideas(context, content_override: text)
    link(highlight, node, "related_idea")
    generation([node], "ideas", "Finding related ideas for #{quoted(text)}")
  end

  defp perform_action(action, context, text, _extra, highlight) when action in @thinking_tools do
    node = GraphActions.apply_thinking_tool_to_text(action, context, text)
    operation = Atom.to_string(action)
    link(highlight, node, operation)

    generation(
      [node],
      operation,
      "Applying #{String.replace(operation, "_", " ")} to #{quoted(text)}"
    )
  end

  defp generation(nodes, operation, label, target_node_id \\ nil) do
    case Enum.filter(nodes, &is_map/1) do
      [] ->
        {:error, "The response could not be started"}

      nodes ->
        {:ok,
         %{
           kind: :generation,
           nodes: nodes,
           operation: operation,
           label: label,
           target_node_id: target_node_id || List.last(nodes).id
         }}
    end
  end

  defp link(nil, _node, _type), do: :ok
  defp link(_highlight, nil, _type), do: :ok
  defp link(highlight, node, type), do: Highlights.add_link(highlight.id, node.id, type)

  defp create_highlight(socket, node_id, offsets, text) do
    attrs = %{
      mudg_id: socket.assigns.graph_id,
      node_id: node_id,
      text_source_type: "node",
      selection_start: offsets["start"] || offsets[:start],
      selection_end: offsets["end"] || offsets[:end],
      selected_text_snapshot: text,
      created_by_user_id: socket.assigns.current_user.id
    }

    case Highlights.create_highlight(attrs) do
      {:ok, highlight} -> highlight
      {:error, _changeset} -> nil
    end
  end

  defp quoted(text) do
    text = String.trim(text)
    shortened = if String.length(text) > 54, do: String.slice(text, 0, 51) <> "…", else: text
    "“#{shortened}”"
  end
end
