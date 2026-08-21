defmodule Dialectic.Responses.LlmInterface do
  @moduledoc """
  Interface for generating LLM responses across various thinking tools and modes.

  This module provides a unified interface for generating AI-powered responses
  for critical thinking tools, dialectical methods, and general explanations.
  """

  # Force recompile
  alias Dialectic.Responses.{
    RequestQueue,
    ModeServer,
    Prompts,
    PromptsStructured
  }

  require Logger

  @type request_result :: {:ok, Oban.Job.t()} | {:error, term()}

  # Define all thinking tools with their metadata
  # This map drives the generic generation for all critical thinking tools
  @thinking_tools %{
    clarify: %{
      prompt_fn: :clarify,
      selection_prompt_fn: :clarify_selection,
      description: "Clarify ambiguous or unclear statements"
    },
    assumptions: %{
      prompt_fn: :assumptions,
      selection_prompt_fn: :assumptions_selection,
      description: "Identify underlying assumptions"
    },
    counterexample: %{
      prompt_fn: :counterexample,
      selection_prompt_fn: :counterexample_selection,
      description: "Generate counterexamples to claims"
    },
    implications: %{
      prompt_fn: :implications,
      selection_prompt_fn: :implications_selection,
      description: "Explore logical implications"
    },
    blind_spots: %{
      prompt_fn: :blind_spots,
      selection_prompt_fn: :blind_spots_selection,
      description: "Identify potential blind spots"
    },
    says_who: %{
      prompt_fn: :says_who,
      selection_prompt_fn: :says_who_selection,
      description: "Question authority and sources"
    },
    who_disagrees: %{
      prompt_fn: :who_disagrees,
      selection_prompt_fn: :who_disagrees_selection,
      description: "Identify opposing viewpoints"
    },
    steel_man: %{
      prompt_fn: :steel_man,
      selection_prompt_fn: :steel_man_selection,
      description: "Construct the strongest version of an argument"
    },
    what_if: %{
      prompt_fn: :what_if,
      selection_prompt_fn: :what_if_selection,
      description: "Explore hypothetical scenarios"
    }
  }

  # Generate public functions for each thinking tool at compile time
  for {tool_name, _metadata} <- @thinking_tools do
    @doc """
    Generate a #{tool_name} response for the given node.

    ## Parameters
      - `node` - The source node to analyze
      - `child` - The target node for the response
      - `graph_id` - The graph identifier
      - `live_view_topic` - The LiveView topic for broadcasting updates
      - `content_override` - Optional text selection to analyze instead of full node content

    ## Returns
      Queues the request and returns the result from `ask_model/5`.
    """
    @spec unquote(:"gen_#{tool_name}")(map(), map(), String.t(), String.t(), String.t() | nil) ::
            request_result()
    def unquote(:"gen_#{tool_name}")(
          node,
          child,
          graph_id,
          live_view_topic,
          content_override \\ nil
        ) do
      generate_thinking_tool_response(
        unquote(tool_name),
        node,
        child,
        graph_id,
        live_view_topic,
        content_override
      )
    end
  end

  @doc """
  Generate a standard explanation response for a node.

  ## Parameters
    - `node` - The node to explain
    - `child` - The target node for the response
    - `graph_id` - The graph identifier
    - `live_view_topic` - The LiveView topic for broadcasting updates

  ## Returns
    Queues the request and returns the result from `ask_model/5`.
  """
  @spec gen_response(map(), map(), String.t(), String.t()) :: request_result()
  def gen_response(node, child, graph_id, live_view_topic) do
    context = GraphManager.build_context(graph_id, node)

    instruction = Prompts.explain(context, node.content)

    queue_response("explain", instruction, child, graph_id, live_view_topic)
  end

  @doc false
  @spec gen_initial_response(map(), map(), String.t(), String.t()) :: request_result()
  def gen_initial_response(node, child, graph_id, live_view_topic) do
    context = GraphManager.build_context(graph_id, node)
    mode = response_mode(child, graph_id)
    instruction = Prompts.initial_explainer(context, node.content || "", mode)
    queue_response("initial_explainer", instruction, child, graph_id, live_view_topic)
  end

  @doc false
  @spec gen_guided_learning_plan(map(), map(), String.t(), String.t()) :: request_result()
  def gen_guided_learning_plan(node, child, graph_id, live_view_topic) do
    context = GraphManager.build_context(graph_id, node)
    instruction = Prompts.guided_learning_plan(context, node.content || "")

    queue_response("guided_learning_plan", instruction, child, graph_id, live_view_topic,
      response_contract: "guided_learning_plan"
    )
  end

  @doc """
  Generate a response with minimal context for selected text explanations.

  Uses only the immediate parent node as context to allow free exploration.

  ## Parameters
    - `node` - The node containing the question about selected text
    - `child` - The target node for the response
    - `graph_id` - The graph identifier
    - `live_view_topic` - The LiveView topic for broadcasting updates

  ## Returns
    Queues the request and returns the result from `ask_model/5`.
  """
  @spec gen_response_minimal_context(map(), map(), String.t(), String.t()) :: request_result()
  def gen_response_minimal_context(node, child, graph_id, live_view_topic) do
    context = immediate_parent_content(graph_id, node, Map.get(node, :source_text))

    instruction =
      case selection_request(node) do
        {:explain, selection} ->
          Prompts.selection(context, selection)

        {:custom_question, selection, question} ->
          Prompts.selection_question(context, selection, question)
      end

    queue_response("selection_minimal", instruction, child, graph_id, live_view_topic)
  end

  @doc """
  Generate a response for a text selection within a node.

  ## Parameters
    - `node` - The source node containing the selection
    - `child` - The target node for the response
    - `graph_id` - The graph identifier
    - `selection` - The selected text to explain
    - `live_view_topic` - The LiveView topic for broadcasting updates

  ## Returns
    Queues the request and returns the result from `ask_model/5`.
  """
  @spec gen_selection_response(map(), map(), String.t(), String.t(), String.t()) ::
          request_result()
  def gen_selection_response(node, child, graph_id, selection, live_view_topic) do
    selection = strip_explain_command(selection)
    context = selection_context(graph_id, node, selection)

    instruction = Prompts.selection(context, selection)

    queue_response("selection", instruction, child, graph_id, live_view_topic)
  end

  @doc """
  Generate a synthesis response combining two nodes.

  ## Parameters
    - `n1` - The first node to synthesize
    - `n2` - The second node to synthesize
    - `child` - The target node for the response
    - `graph_id` - The graph identifier
    - `live_view_topic` - The LiveView topic for broadcasting updates

  ## Returns
    Queues the request and returns the result from `ask_model/5`.
  """
  @spec gen_synthesis(map(), map(), map(), String.t(), String.t()) :: request_result()
  def gen_synthesis(n1, n2, child, graph_id, live_view_topic) do
    # TODO - Add n2 context ?? need to enforce limit??
    context1 = GraphManager.build_context(graph_id, n1)
    context2 = GraphManager.build_context(graph_id, n2)

    instruction =
      Prompts.synthesis(context1, context2, n1.content, n2.content)

    queue_response("synthesis", instruction, child, graph_id, live_view_topic)
  end

  @doc """
  Generate a thesis (supporting argument) for a node.

  ## Parameters
    - `node` - The node to generate a thesis for
    - `child` - The target node for the response
    - `graph_id` - The graph identifier
    - `live_view_topic` - The LiveView topic for broadcasting updates
    - `content_override` - Optional text selection to analyze instead of full node content

  ## Returns
    Queues the request and returns the result from `ask_model/5`.
  """
  @spec gen_thesis(map(), map(), String.t(), String.t(), String.t() | nil) :: request_result()
  def gen_thesis(node, child, graph_id, live_view_topic, content_override \\ nil) do
    {context, content} = resolve_context_and_content(graph_id, node, content_override)

    instruction =
      if content_override do
        Prompts.thesis_selection(context, content)
      else
        Prompts.thesis(context, content)
      end

    queue_response("thesis", instruction, child, graph_id, live_view_topic)
  end

  @doc """
  Generate an antithesis (opposing argument) for a node.

  ## Parameters
    - `node` - The node to generate an antithesis for
    - `child` - The target node for the response
    - `graph_id` - The graph identifier
    - `live_view_topic` - The LiveView topic for broadcasting updates
    - `content_override` - Optional text selection to analyze instead of full node content

  ## Returns
    Queues the request and returns the result from `ask_model/5`.
  """
  @spec gen_antithesis(map(), map(), String.t(), String.t(), String.t() | nil) :: request_result()
  def gen_antithesis(node, child, graph_id, live_view_topic, content_override \\ nil) do
    {context, content} = resolve_context_and_content(graph_id, node, content_override)

    instruction =
      if content_override do
        Prompts.antithesis_selection(context, content)
      else
        Prompts.antithesis(context, content)
      end

    queue_response("antithesis", instruction, child, graph_id, live_view_topic)
  end

  @doc """
  Generate related ideas for a node.

  ## Parameters
    - `node` - The node to find related ideas for
    - `child` - The target node for the response
    - `graph_id` - The graph identifier
    - `live_view_topic` - The LiveView topic for broadcasting updates
    - `content_override` - Optional text selection to analyze instead of full node content

  ## Returns
    Queues the request and returns the result from `ask_model/5`.
  """
  @spec gen_related_ideas(map(), map(), String.t(), String.t(), String.t() | nil) ::
          request_result()
  def gen_related_ideas(node, child, graph_id, live_view_topic, content_override \\ nil) do
    context =
      if content_override do
        selection_context(graph_id, node, content_override)
      else
        [GraphManager.build_context(graph_id, node), to_string(node.content || "")]
        |> Enum.reject(&(&1 == ""))
        |> Enum.join("\n\n")
      end

    instruction =
      if content_override do
        Prompts.related_ideas_selection(context, content_override)
      else
        Prompts.related_ideas(context, node.content)
      end

    queue_response("related_ideas", instruction, child, graph_id, live_view_topic)
  end

  # Private Functions

  # Core generic function that handles all thinking tool generation
  @spec generate_thinking_tool_response(
          atom(),
          map(),
          map(),
          String.t(),
          String.t(),
          String.t() | nil
        ) :: request_result()
  defp generate_thinking_tool_response(
         tool_name,
         node,
         child,
         graph_id,
         live_view_topic,
         content_override
       ) do
    tool_metadata = Map.fetch!(@thinking_tools, tool_name)

    {context, content} = resolve_context_and_content(graph_id, node, content_override)

    instruction = build_instruction(tool_metadata, context, content, content_override)

    queue_response(to_string(tool_name), instruction, child, graph_id, live_view_topic)
  end

  # Build the instruction for a thinking tool based on whether we have a content override
  @spec build_instruction(map(), String.t(), String.t(), String.t() | nil) :: String.t()
  defp build_instruction(tool_metadata, context, content, content_override) do
    prompt_fn =
      if content_override do
        tool_metadata.selection_prompt_fn
      else
        tool_metadata.prompt_fn
      end

    apply(Prompts, prompt_fn, [context, content])
  end

  @doc false
  @spec resolve_context_and_content(String.t(), map(), String.t() | nil) ::
          {String.t(), String.t()}
  defp resolve_context_and_content(graph_id, node, content_override) do
    base_context = GraphManager.build_context(graph_id, node)

    if content_override do
      {join_context(selection_window(node.content, content_override), base_context),
       content_override}
    else
      {base_context, node.content || ""}
    end
  end

  defp selection_context(graph_id, node, selection) do
    local_context = selection_window(node.content, selection)
    join_context(local_context, GraphManager.build_context(graph_id, node))
  end

  defp immediate_parent_content(graph_id, node, selection) do
    case Map.get(node, :parents, []) do
      [parent | _] when is_map(parent) ->
        selection_window(Map.get(parent, :content), selection)

      [parent_id | _] ->
        case GraphManager.find_node_by_id(graph_id, parent_id) do
          nil -> ""
          parent -> selection_window(parent.content, selection)
        end

      _ ->
        ""
    end
  end

  defp selection_window(content, selection) when is_binary(content) and is_binary(selection) do
    case String.split(content, selection, parts: 2) do
      [before, after_text] ->
        before = String.slice(before, max(String.length(before) - 450, 0), 450)
        after_text = String.slice(after_text, 0, 450)
        before <> selection <> after_text

      [_content_without_selection] ->
        String.slice(content, 0, 1_000)
    end
  end

  defp selection_window(content, _selection), do: to_string(content || "")

  defp join_context(local_content, ancestor_context) do
    [to_string(local_content || ""), ancestor_context]
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n\n")
  end

  defp selection_request(node) do
    content = node.content || ""
    source_text = Map.get(node, :source_text) || ""

    case Map.get(node, :prompt_kind) do
      "selection_explain_question" ->
        {:explain, source_text}

      "selection_question_input" ->
        {:custom_question, source_text, content}

      _legacy ->
        if String.starts_with?(content, "Please explain:") do
          {:explain, strip_explain_command(content)}
        else
          {:custom_question, source_text, content}
        end
    end
  end

  defp strip_explain_command(content) do
    content
    |> to_string()
    |> String.replace(~r/^Please explain:\s*/, "")
    |> String.trim()
  end

  defp queue_response(action, instruction, child, graph_id, live_view_topic, opts \\ []) do
    mode = response_mode(child, graph_id)
    system_prompt = PromptsStructured.system_preamble(mode)
    log_prompt(action, graph_id, mode, system_prompt, instruction)
    ask_model(instruction, system_prompt, child, graph_id, live_view_topic, mode, opts)
  end

  defp response_mode(child, graph_id) do
    case Map.get(child, :response_level) do
      "simple" -> :high_school
      "high_school" -> :high_school
      "university" -> :university
      "expert" -> :expert
      _other -> ModeServer.get_mode(graph_id)
    end
  end

  @spec log_prompt(String.t(), String.t(), ModeServer.mode(), String.t(), String.t()) :: :ok
  defp log_prompt(action, graph_id, mode, system_prompt, instruction) do
    Logger.debug(fn ->
      "[LlmInterface] action=#{action} mode=#{mode} graph_id=#{inspect(graph_id)}\nSYSTEM_PROMPT_START\n#{system_prompt}\nSYSTEM_PROMPT_END\nINSTRUCTION_START\n#{instruction}\nINSTRUCTION_END"
    end)
  end

  @doc """
  Queue a model request for processing.

  ## Parameters
    - `instruction` - The instruction/prompt for the model
    - `system_prompt` - The system-level prompt for the model
    - `to_node` - The target node for the response
    - `graph_id` - The graph identifier
    - `live_view_topic` - The LiveView topic for broadcasting updates

  ## Returns
    The result of `RequestQueue.add/5`.
  """
  @spec ask_model(String.t(), String.t(), map(), String.t(), String.t()) :: request_result()
  def ask_model(instruction, system_prompt, to_node, graph_id, live_view_topic) do
    mode =
      case PromptsStructured.mode_from_preamble(system_prompt) do
        {:ok, prompt_mode} -> prompt_mode
        :error -> ModeServer.get_mode(graph_id)
      end

    ask_model(instruction, system_prompt, to_node, graph_id, live_view_topic, mode, [])
  end

  @doc false
  @spec ask_model(String.t(), String.t(), map(), String.t(), String.t(), ModeServer.mode()) ::
          request_result()
  def ask_model(instruction, system_prompt, to_node, graph_id, live_view_topic, mode, opts \\ []) do
    node_id = if is_map(to_node), do: to_node.id, else: to_node
    response_level = mode |> PromptsStructured.response_profile() |> Map.fetch!(:key)
    GraphManager.update_vertex_fields(graph_id, node_id, %{response_level: response_level})

    RequestQueue.add(
      instruction,
      system_prompt,
      to_node,
      graph_id,
      live_view_topic,
      Keyword.put(opts, :mode, mode)
    )
  end
end
