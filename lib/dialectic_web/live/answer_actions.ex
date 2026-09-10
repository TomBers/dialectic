defmodule DialecticWeb.AnswerActions do
  alias Dialectic.Graph.GraphActions
  alias DialecticWeb.GraphHelpers

  @tools ~w(clarify assumptions counterexample implications blind_spots says_who who_disagrees steel_man what_if)a
  @actions Map.new(
             [:comment, :ask_question, :bookmark, :explain, :pros_cons, :related_ideas] ++ @tools,
             &{Atom.to_string(&1), &1}
           )

  def perform(socket, params) do
    with {:ok, action} <- Map.fetch(@actions, params["action"]),
         {:ok, node} <- target(socket, params["nodeId"], action),
         :ok <- validate_input(socket, action, params) do
      perform_action(action, socket, node, params)
    else
      :error -> {:error, "Choose an available response action."}
      error -> error
    end
  end

  defp target(socket, node_id, action) do
    node = if is_binary(node_id), do: GraphActions.find_node(socket.assigns.graph_id, node_id)

    cond do
      !socket.assigns.can_edit && action != :bookmark ->
        {:error, "This graph is locked"}

      is_nil(node) || node.deleted || Map.get(node, :compound, false) ||
          GraphHelpers.origin_node?(node) ->
        {:error, "Choose an existing response to continue."}

      true ->
        {:ok, node}
    end
  end

  defp validate_input(socket, action, params) do
    cond do
      action in [:ask_question, :comment] && GraphHelpers.inquiry_content(params["input"]) == "" ->
        {:error, "Write a comment or question first."}

      is_nil(socket.assigns.current_user) && action == :bookmark ->
        {:error, "Sign in to bookmark this response. Your draft will stay here."}

      is_nil(socket.assigns.current_user) && action == :ask_question && guided_learning?(params) ->
        {:error, "Sign in to add a personal learning plan. Your draft will stay here."}

      true ->
        :ok
    end
  end

  defp perform_action(:bookmark, socket, node, _params) do
    bookmarked? =
      node.id in Dialectic.DbActions.Notes.list_noted_node_ids(
        socket.assigns.graph_id,
        socket.assigns.current_user
      )

    action = if bookmarked?, do: :unnote, else: :note
    {:ok, _, _} = GraphHelpers.handle_note(socket, node.id, action)
    GraphManager.save_graph(socket.assigns.graph_id)
    {:ok, %{kind: :bookmark, node_id: node.id, bookmarked: !bookmarked?}}
  end

  defp perform_action(:comment, socket, node, params) do
    case GraphActions.comment(
           GraphHelpers.graph_action_params(socket, node),
           GraphHelpers.inquiry_content(params["input"])
         ) do
      nil -> {:error, "Your thought could not be saved. Please try again."}
      comment -> {:ok, %{kind: :comment, node: comment}}
    end
  end

  defp perform_action(:ask_question, socket, node, params) do
    {_, answer} =
      GraphActions.ask_and_answer(
        GraphHelpers.graph_action_params(socket, node),
        GraphHelpers.inquiry_content(params["input"]),
        guided_learning: guided_learning?(params)
      )

    generation([answer], "answer", "Answering your question", created_parents: true)
  end

  defp perform_action(:explain, socket, node, _params) do
    {_, answer} =
      GraphActions.ask_and_answer(
        GraphHelpers.graph_action_params(socket, node),
        "Please explain this response in simpler terms."
      )

    generation([answer], "explain", "Explaining this response", created_parents: true)
  end

  defp perform_action(:pros_cons, socket, node, _params) do
    nodes = GraphActions.branch(GraphHelpers.graph_action_params(socket, node))
    generation(nodes, "branch", "Testing both sides", target_node_id: node.id)
  end

  defp perform_action(:related_ideas, socket, node, _params) do
    related = GraphActions.related_ideas(GraphHelpers.graph_action_params(socket, node))
    generation([related], "ideas", "Finding related ideas")
  end

  defp perform_action(action, socket, node, _params) when action in @tools do
    result =
      GraphActions.apply_thinking_tool(action, GraphHelpers.graph_action_params(socket, node))

    generation([result], Atom.to_string(action), "Exploring this response")
  end

  defp guided_learning?(params), do: params["guided_learning"] in [true, "true", "on", "1"]

  defp generation(nodes, operation, label, opts \\ []) do
    case Enum.filter(nodes, &is_map/1) do
      [] ->
        {:error, "The response could not be started. Please try again."}

      nodes ->
        created_nodes =
          if Keyword.get(opts, :created_parents, false),
            do: Enum.flat_map(nodes, &[&1 | &1.parents]),
            else: nodes

        {:ok,
         %{
           kind: :generation,
           nodes: nodes,
           created_node_ids: Enum.map(created_nodes, & &1.id),
           operation: operation,
           label: label,
           target_node_id: Keyword.get(opts, :target_node_id, List.last(nodes).id)
         }}
    end
  end
end
