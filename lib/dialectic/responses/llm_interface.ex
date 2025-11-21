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

  def regenerate_node(node_id, graph_id, live_view_topic) do
    case GraphManager.find_node_by_id(graph_id, node_id) do
      nil ->
        Logger.warning("regenerate_node: Node #{node_id} not found in graph #{graph_id}")
        :ok

      target_node ->
        parents = target_node.parents

        case target_node.class do
          "thesis" ->
            if parent = List.first(parents),
              do: gen_thesis(parent, target_node, graph_id, live_view_topic)

          "antithesis" ->
            if parent = List.first(parents),
              do: gen_antithesis(parent, target_node, graph_id, live_view_topic)

          "deepdive" ->
            if parent = List.first(parents),
              do: gen_deepdive(parent, target_node, graph_id, live_view_topic)

          "ideas" ->
            if parent = List.first(parents),
              do: gen_related_ideas(parent, target_node, graph_id, live_view_topic)

          "answer" ->
            if parent = List.first(parents),
              do: gen_response(parent, target_node, graph_id, live_view_topic)

          "synthesis" ->
            if length(parents) >= 2 do
              [p1, p2 | _] = parents
              gen_synthesis(p1, p2, target_node, graph_id, live_view_topic)
            end

          _ ->
            Logger.warning(
              "regenerate_node: Unsupported class #{target_node.class} for node #{node_id}"
            )

            :ok
        end
    end
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
