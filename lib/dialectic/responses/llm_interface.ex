defmodule Dialectic.Responses.LlmInterface do
  alias Dialectic.Responses.{
    RequestQueue,
    ModeServer,
    Prompts,
    PromptsStructured,
    PromptsCreative
  }

  require Logger

  def gen_response(node, child, graph_id, live_view_topic) do
    context = GraphManager.build_context(graph_id, node)

    instruction =
      Prompts.explain(context, node.content)

    system_prompt = get_system_prompt(graph_id)
    log_prompt("explain", graph_id, system_prompt, instruction)
    ask_model(instruction, system_prompt, child, graph_id, live_view_topic)
  end

  @doc """
  Generate a response with minimal context for selected text explanations.
  Uses only the immediate parent node as context to allow free exploration.
  """
  def gen_response_minimal_context(node, child, graph_id, live_view_topic) do
    # Build minimal context - only the immediate parent node
    context =
      case node.parents do
        [parent_id | _] ->
          case GraphManager.find_node_by_id(graph_id, parent_id) do
            nil -> ""
            parent -> parent.content || ""
          end

        _ ->
          ""
      end

    # Extract the selected text from the question node
    selection =
      node.content
      |> String.replace(~r/^Please explain:\s*/, "")
      |> String.trim()

    instruction = Prompts.selection(context, selection)

    system_prompt = get_system_prompt(graph_id)
    log_prompt("selection_minimal", graph_id, system_prompt, instruction)
    ask_model(instruction, system_prompt, child, graph_id, live_view_topic)
  end

  def gen_selection_response(node, child, graph_id, selection, live_view_topic) do
    context = GraphManager.build_context(graph_id, node)

    instruction =
      Prompts.selection(context, selection)

    system_prompt = get_system_prompt(graph_id)
    log_prompt("selection", graph_id, system_prompt, instruction)
    ask_model(instruction, system_prompt, child, graph_id, live_view_topic)
  end

  def gen_synthesis(n1, n2, child, graph_id, live_view_topic) do
    # TODO - Add n2 context ?? need to enforce limit??
    context1 = GraphManager.build_context(graph_id, n1)
    context2 = GraphManager.build_context(graph_id, n2)

    instruction =
      Prompts.synthesis(context1, context2, n1.content, n2.content)

    system_prompt = get_system_prompt(graph_id)
    log_prompt("synthesis", graph_id, system_prompt, instruction)
    ask_model(instruction, system_prompt, child, graph_id, live_view_topic)
  end

  def gen_thesis(node, child, graph_id, live_view_topic) do
    context = GraphManager.build_context(graph_id, node)

    instruction =
      Prompts.thesis(context, node.content)

    system_prompt = get_system_prompt(graph_id)
    log_prompt("thesis", graph_id, system_prompt, instruction)
    ask_model(instruction, system_prompt, child, graph_id, live_view_topic)
  end

  def gen_antithesis(node, child, graph_id, live_view_topic) do
    context = GraphManager.build_context(graph_id, node)

    instruction =
      Prompts.antithesis(context, node.content)

    system_prompt = get_system_prompt(graph_id)
    log_prompt("antithesis", graph_id, system_prompt, instruction)
    ask_model(instruction, system_prompt, child, graph_id, live_view_topic)
  end

  def gen_related_ideas(node, child, graph_id, live_view_topic) do
    base = GraphManager.build_context(graph_id, node)

    context =
      [base, to_string(node.content || "")]
      |> Enum.reject(&(&1 == ""))
      |> Enum.join("\n\n")

    instruction =
      Prompts.related_ideas(context, node.content)

    system_prompt = get_system_prompt(graph_id)
    log_prompt("related_ideas", graph_id, system_prompt, instruction)
    ask_model(instruction, system_prompt, child, graph_id, live_view_topic)
  end

  def gen_deepdive(node, child, graph_id, live_view_topic) do
    context = to_string(node.content || "")

    instruction =
      Prompts.deep_dive(context, node.content)

    system_prompt = get_system_prompt(graph_id)
    log_prompt("deep_dive", graph_id, system_prompt, instruction)
    ask_model(instruction, system_prompt, child, graph_id, live_view_topic)
  end

  defp get_system_prompt(graph_id) do
    case ModeServer.get_mode(graph_id) do
      :creative -> PromptsCreative.system_preamble()
      _ -> PromptsStructured.system_preamble()
    end
  end

  defp log_prompt(action, graph_id, system_prompt, instruction) do
    mode = ModeServer.get_mode(graph_id)

    Logger.debug(fn ->
      "[LlmInterface] action=#{action} mode=#{mode} graph_id=#{inspect(graph_id)}\nSYSTEM_PROMPT_START\n#{system_prompt}\nSYSTEM_PROMPT_END\nINSTRUCTION_START\n#{instruction}\nINSTRUCTION_END"
    end)
  end

  def ask_model(instruction, system_prompt, to_node, graph_id, live_view_topic) do
    RequestQueue.add(
      instruction,
      system_prompt,
      to_node,
      graph_id,
      live_view_topic
    )
  end
end
