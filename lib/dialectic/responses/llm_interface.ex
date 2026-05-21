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

    system_prompt = get_system_prompt(graph_id)
    log_prompt("explain", graph_id, system_prompt, instruction)
    ask_model(instruction, system_prompt, child, graph_id, live_view_topic)
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
    context = GraphManager.build_context(graph_id, node)

    instruction = Prompts.selection(context, selection)

    system_prompt = get_system_prompt(graph_id)
    log_prompt("selection", graph_id, system_prompt, instruction)
    ask_model(instruction, system_prompt, child, graph_id, live_view_topic)
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

    system_prompt = get_system_prompt(graph_id)
    log_prompt("synthesis", graph_id, system_prompt, instruction)
    ask_model(instruction, system_prompt, child, graph_id, live_view_topic)
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

    system_prompt = get_system_prompt(graph_id)
    log_prompt("thesis", graph_id, system_prompt, instruction)
    ask_model(instruction, system_prompt, child, graph_id, live_view_topic)
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

    system_prompt = get_system_prompt(graph_id)
    log_prompt("antithesis", graph_id, system_prompt, instruction)
    ask_model(instruction, system_prompt, child, graph_id, live_view_topic)
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

    system_prompt = get_system_prompt(graph_id)
    log_prompt(to_string(tool_name), graph_id, system_prompt, instruction)
    ask_model(instruction, system_prompt, child, graph_id, live_view_topic)
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
      # Selection-targeted tools should analyze the selected text while retaining
      # the surrounding graph context as the Foundation for the prompt.
      {base_context, content_override}
    else
      {base_context, node.content || ""}
    end
  end

  @spec get_system_prompt(String.t()) :: String.t()
  defp get_system_prompt(graph_id) do
    mode = ModeServer.get_mode(graph_id)
    PromptsStructured.system_preamble(mode)
  end

  @spec log_prompt(String.t(), String.t(), String.t(), String.t()) :: :ok
  defp log_prompt(action, graph_id, system_prompt, instruction) do
    mode = ModeServer.get_mode(graph_id)

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
    RequestQueue.add(
      instruction,
      system_prompt,
      to_node,
      graph_id,
      live_view_topic
    )
  end
end
