defmodule Dialectic.Responses.LlmInterface do
  # Force recompile
  alias Dialectic.Responses.{
    RequestQueue,
    ModeServer,
    Prompts,
    PromptsStructured
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

  def gen_thesis(node, child, graph_id, live_view_topic, content_override \\ nil) do
    {context, content} = resolve_context_and_content(graph_id, node, content_override)

    instruction =
      if content_override do
        Prompts.thesis_selection(context, content)
      else
        Prompts.thesis(context, content)
      end

    system_prompt = get_system_prompt(graph_id)
    log_prompt("thesis", graph_id, system_prompt, instruction)
    ask_model(instruction, system_prompt, child, graph_id, live_view_topic)
  end

  def gen_antithesis(node, child, graph_id, live_view_topic, content_override \\ nil) do
    {context, content} = resolve_context_and_content(graph_id, node, content_override)

    instruction =
      if content_override do
        Prompts.antithesis_selection(context, content)
      else
        Prompts.antithesis(context, content)
      end

    system_prompt = get_system_prompt(graph_id)
    log_prompt("antithesis", graph_id, system_prompt, instruction)
    ask_model(instruction, system_prompt, child, graph_id, live_view_topic)
  end

  def gen_related_ideas(node, child, graph_id, live_view_topic, content_override \\ nil) do
    base = GraphManager.build_context(graph_id, node)

    context =
      [base, to_string(node.content || "")]
      |> Enum.reject(&(&1 == ""))
      |> Enum.join("\n\n")

    instruction =
      if content_override do
        Prompts.related_ideas_selection(context, content_override)
      else
        Prompts.related_ideas(context, node.content)
      end

    system_prompt = get_system_prompt(graph_id)
    log_prompt("related_ideas", graph_id, system_prompt, instruction)
    ask_model(instruction, system_prompt, child, graph_id, live_view_topic)
  end

  def gen_deepdive(node, child, graph_id, live_view_topic, content_override \\ nil) do
    context = to_string(node.content || "")

    instruction =
      if content_override do
        Prompts.deep_dive_selection(context, content_override)
      else
        Prompts.deep_dive(context, node.content)
      end

    system_prompt = get_system_prompt(graph_id)
    log_prompt("deep_dive", graph_id, system_prompt, instruction)
    ask_model(instruction, system_prompt, child, graph_id, live_view_topic)
  end

  # ===========================================================================
  # Cluster 1 — Core Inquiry Moves
  # ===========================================================================

  def gen_clarify(node, child, graph_id, live_view_topic, content_override \\ nil) do
    {context, content} = resolve_context_and_content(graph_id, node, content_override)

    instruction =
      if content_override do
        Prompts.clarify_selection(context, content)
      else
        Prompts.clarify(context, content)
      end

    system_prompt = get_system_prompt(graph_id)
    log_prompt("clarify", graph_id, system_prompt, instruction)
    ask_model(instruction, system_prompt, child, graph_id, live_view_topic)
  end

  def gen_assumptions(node, child, graph_id, live_view_topic, content_override \\ nil) do
    {context, content} = resolve_context_and_content(graph_id, node, content_override)

    instruction =
      if content_override do
        Prompts.assumptions_selection(context, content)
      else
        Prompts.assumptions(context, content)
      end

    system_prompt = get_system_prompt(graph_id)
    log_prompt("assumptions", graph_id, system_prompt, instruction)
    ask_model(instruction, system_prompt, child, graph_id, live_view_topic)
  end

  def gen_counterexample(node, child, graph_id, live_view_topic, content_override \\ nil) do
    {context, content} = resolve_context_and_content(graph_id, node, content_override)

    instruction =
      if content_override do
        Prompts.counterexample_selection(context, content)
      else
        Prompts.counterexample(context, content)
      end

    system_prompt = get_system_prompt(graph_id)
    log_prompt("counterexample", graph_id, system_prompt, instruction)
    ask_model(instruction, system_prompt, child, graph_id, live_view_topic)
  end

  def gen_implications(node, child, graph_id, live_view_topic, content_override \\ nil) do
    {context, content} = resolve_context_and_content(graph_id, node, content_override)

    instruction =
      if content_override do
        Prompts.implications_selection(context, content)
      else
        Prompts.implications(context, content)
      end

    system_prompt = get_system_prompt(graph_id)
    log_prompt("implications", graph_id, system_prompt, instruction)
    ask_model(instruction, system_prompt, child, graph_id, live_view_topic)
  end

  def gen_blind_spots(node, child, graph_id, live_view_topic, content_override \\ nil) do
    {context, content} = resolve_context_and_content(graph_id, node, content_override)

    instruction =
      if content_override do
        Prompts.blind_spots_selection(context, content)
      else
        Prompts.blind_spots(context, content)
      end

    system_prompt = get_system_prompt(graph_id)
    log_prompt("blind_spots", graph_id, system_prompt, instruction)
    ask_model(instruction, system_prompt, child, graph_id, live_view_topic)
  end

  # ===========================================================================
  # Cluster 2 — Context and Dialectical Expansion
  # ===========================================================================

  def gen_says_who(node, child, graph_id, live_view_topic, content_override \\ nil) do
    {context, content} = resolve_context_and_content(graph_id, node, content_override)

    instruction =
      if content_override do
        Prompts.says_who_selection(context, content)
      else
        Prompts.says_who(context, content)
      end

    system_prompt = get_system_prompt(graph_id)
    log_prompt("says_who", graph_id, system_prompt, instruction)
    ask_model(instruction, system_prompt, child, graph_id, live_view_topic)
  end

  def gen_who_disagrees(node, child, graph_id, live_view_topic, content_override \\ nil) do
    {context, content} = resolve_context_and_content(graph_id, node, content_override)

    instruction =
      if content_override do
        Prompts.who_disagrees_selection(context, content)
      else
        Prompts.who_disagrees(context, content)
      end

    system_prompt = get_system_prompt(graph_id)
    log_prompt("who_disagrees", graph_id, system_prompt, instruction)
    ask_model(instruction, system_prompt, child, graph_id, live_view_topic)
  end

  def gen_analogy(node, child, graph_id, live_view_topic, content_override \\ nil) do
    {context, content} = resolve_context_and_content(graph_id, node, content_override)

    instruction =
      if content_override do
        Prompts.analogy_selection(context, content)
      else
        Prompts.analogy(context, content)
      end

    system_prompt = get_system_prompt(graph_id)
    log_prompt("analogy", graph_id, system_prompt, instruction)
    ask_model(instruction, system_prompt, child, graph_id, live_view_topic)
  end

  def gen_steel_man(node, child, graph_id, live_view_topic, content_override \\ nil) do
    {context, content} = resolve_context_and_content(graph_id, node, content_override)

    instruction =
      if content_override do
        Prompts.steel_man_selection(context, content)
      else
        Prompts.steel_man(context, content)
      end

    system_prompt = get_system_prompt(graph_id)
    log_prompt("steel_man", graph_id, system_prompt, instruction)
    ask_model(instruction, system_prompt, child, graph_id, live_view_topic)
  end

  def gen_what_if(node, child, graph_id, live_view_topic, content_override \\ nil) do
    {context, content} = resolve_context_and_content(graph_id, node, content_override)

    instruction =
      if content_override do
        Prompts.what_if_selection(context, content)
      else
        Prompts.what_if(context, content)
      end

    system_prompt = get_system_prompt(graph_id)
    log_prompt("what_if", graph_id, system_prompt, instruction)
    ask_model(instruction, system_prompt, child, graph_id, live_view_topic)
  end

  # ===========================================================================
  # Cluster 3 — Clarity and Communication
  # ===========================================================================

  def gen_simplify(node, child, graph_id, live_view_topic, content_override \\ nil) do
    {context, content} = resolve_context_and_content(graph_id, node, content_override)

    instruction =
      if content_override do
        Prompts.simplify_selection(context, content)
      else
        Prompts.simplify(context, content)
      end

    system_prompt = get_system_prompt(graph_id)
    log_prompt("simplify", graph_id, system_prompt, instruction)
    ask_model(instruction, system_prompt, child, graph_id, live_view_topic)
  end

  defp resolve_context_and_content(graph_id, node, content_override) do
    base_context = GraphManager.build_context(graph_id, node)

    if content_override do
      # Include node content in context if we are focusing on a sub-selection
      ctx =
        [base_context, to_string(node.content || "")]
        |> Enum.reject(&(&1 == ""))
        |> Enum.join("\n\n")

      {ctx, content_override}
    else
      {base_context, node.content}
    end
  end

  defp get_system_prompt(graph_id) do
    mode = ModeServer.get_mode(graph_id)
    PromptsStructured.system_preamble(mode)
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
