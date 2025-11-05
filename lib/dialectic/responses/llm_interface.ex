defmodule Dialectic.Responses.LlmInterface do
  @moduledoc """
  High-level interface for generating prompts with optional graph context and
  enqueueing the final request for processing.

  Responsibilities:
  - Build context strings from the graph (only here).
  - Delegate question body wording to `Dialectic.Responses.PromptBuilder` (pure).
  - Compose the final prompt using `Dialectic.Responses.Modes`.
  - Enqueue via the request queue (no wording here).

  This separation keeps wording easy to test and evolve independently.
  """

  alias Dialectic.Responses.{RequestQueue, PromptBuilder, Modes}

  # ------------------------------------------------------------------------------
  # Public API – wrappers without mode (kept for test compatibility)
  # ------------------------------------------------------------------------------

  @doc "Generate a standard response for a node (no explicit mode)."
  def gen_response(node, child, graph_id, live_view_topic),
    do: gen_response(node, child, graph_id, live_view_topic, nil)

  @doc "Generate a selection response for a node (no explicit mode)."
  def gen_selection_response(node, child, graph_id, selection, live_view_topic),
    do: gen_selection_response(node, child, graph_id, selection, live_view_topic, nil)

  @doc "Generate a synthesis from two nodes (no explicit mode)."
  def gen_synthesis(n1, n2, child, graph_id, live_view_topic),
    do: gen_synthesis(n1, n2, child, graph_id, live_view_topic, nil)

  @doc "Generate a thesis for a node (no explicit mode)."
  def gen_thesis(node, child, graph_id, live_view_topic),
    do: gen_thesis(node, child, graph_id, live_view_topic, nil)

  @doc "Generate an antithesis for a node (no explicit mode)."
  def gen_antithesis(node, child, graph_id, live_view_topic),
    do: gen_antithesis(node, child, graph_id, live_view_topic, nil)

  @doc "Generate a related-ideas prompt for a node (no explicit mode)."
  def gen_related_ideas(node, child, graph_id, live_view_topic),
    do: gen_related_ideas(node, child, graph_id, live_view_topic, nil)

  @doc "Generate a deepdive for a node (no explicit mode)."
  def gen_deepdive(node, child, graph_id, live_view_topic),
    do: gen_deepdive(node, child, graph_id, live_view_topic, nil)

  # ------------------------------------------------------------------------------
  # Public API – main entry points (with mode)
  # ------------------------------------------------------------------------------

  @doc """
  Generate a response prompt for a node, composing graph context + question body
  and enqueueing the request.
  """
  def gen_response(node, child, graph_id, live_view_topic, mode) do
    context = build_context(graph_id, node)
    body = PromptBuilder.question_response(to_string(node.content || ""))
    qn = wrap_context(context, body)
    ask_model(qn, child, graph_id, live_view_topic, mode)
  end

  @doc """
  Generate a selection response: uses graph context + selection body.
  """
  def gen_selection_response(node, child, graph_id, selection, live_view_topic, mode) do
    context = build_context(graph_id, node)

    # Build the standard selection body via PromptBuilder and keep compatibility
    # with prior wording header expected in some tests by adjusting the header line.
    body =
      selection
      |> to_string()
      |> PromptBuilder.question_selection()
      |> ensure_selection_header("Instruction (apply to the context and current node):")

    qn = wrap_context(context, body)
    ask_model(qn, child, graph_id, live_view_topic, mode)
  end

  @doc """
  Generate a synthesis from two nodes, including each node's context.
  """
  def gen_synthesis(n1, n2, child, graph_id, live_view_topic, mode) do
    context1 = build_context(graph_id, n1)
    context2 = build_context(graph_id, n2)

    body =
      PromptBuilder.question_synthesis(
        to_string(n1.content || ""),
        to_string(n2.content || "")
      )

    qn = wrap_dual_context(context1, context2, body)
    ask_model(qn, child, graph_id, live_view_topic, mode)
  end

  @doc """
  Generate a thesis (short, rigorous support) for a node.
  """
  def gen_thesis(node, child, graph_id, live_view_topic, mode) do
    context = build_context(graph_id, node)
    body = PromptBuilder.question_thesis(to_string(node.content || ""))
    qn = wrap_context(context, body)
    ask_model(qn, child, graph_id, live_view_topic, mode)
  end

  @doc """
  Generate an antithesis (short, rigorous critique) for a node.
  """
  def gen_antithesis(node, child, graph_id, live_view_topic, mode) do
    context = build_context(graph_id, node)
    body = PromptBuilder.question_antithesis(to_string(node.content || ""))
    qn = wrap_context(context, body)
    ask_model(qn, child, graph_id, live_view_topic, mode)
  end

  @doc """
  Generate related ideas to explore next for a node (title is derived from first line).
  """
  def gen_related_ideas(node, child, graph_id, live_view_topic, mode) do
    context = build_context(graph_id, node)

    title =
      node
      |> then(&to_string((&1 && &1.content) || ""))
      |> String.replace("**", "")
      |> String.split("\n")
      |> List.first()
      |> to_string()
      |> String.replace(~r/^\s*[#]{1,6}\s*/u, "")
      |> String.replace(~r/^Title:\s*/i, "")
      |> String.trim()

    body = PromptBuilder.question_related_ideas(title)
    qn = wrap_context(context, body)
    ask_model(qn, child, graph_id, live_view_topic, mode)
  end

  @doc """
  Generate a deep dive (advanced explanation). For this one, the "context" is the
  node's literal content, matching previous behavior.
  """
  def gen_deepdive(node, child, graph_id, live_view_topic, mode) do
    context = to_string(node.content || "")
    body = PromptBuilder.question_deepdive(to_string(node.content || ""))
    qn = wrap_context(context, body)
    ask_model(qn, child, graph_id, live_view_topic, mode)
  end

  # ------------------------------------------------------------------------------
  # Request enqueueing
  # ------------------------------------------------------------------------------

  @doc "Enqueue a composed question using the default mode."
  def ask_model(question, to_node, graph_id, live_view_topic),
    do: ask_model(question, to_node, graph_id, live_view_topic, nil)

  @doc """
  Compose the final prompt with the selected mode and enqueue it.
  """
  def ask_model(question, to_node, graph_id, live_view_topic, mode) do
    prompt = Modes.compose(question, mode || Modes.default())

    RequestQueue.add(
      prompt,
      to_node,
      graph_id,
      live_view_topic
    )
  end

  # ------------------------------------------------------------------------------
  # Developer helpers
  # ------------------------------------------------------------------------------

  @doc """
  Convenience: delegate to `Modes.compose/2` to build a final prompt from a body and mode.
  """
  def compose(question_body, mode \\ nil) when is_binary(question_body) do
    Modes.compose(question_body, mode || Modes.default())
  end

  @doc """
  Pretty-print all prompts for a node for a given mode (or default).
  This is a console utility for quick iteration, not used in tests.
  """
  def print_all_prompts(node, graph_id, mode \\ nil, opts \\ []) do
    other = Keyword.get(opts, :other_node)
    selection = Keyword.get(opts, :selection)

    resolved_mode = mode || Modes.default()
    mode_info = Modes.fetch(resolved_mode)
    mode_label = Map.get(mode_info, :label, to_string(resolved_mode))

    title =
      node
      |> Map.get(:content)
      |> to_string()

    first_line =
      title
      |> String.split("\n")
      |> Enum.at(0)
      |> to_string()
      |> String.replace(~r/\s+/, " ")

    preview =
      if String.length(first_line) > 120 do
        String.slice(first_line, 0, 117) <> "..."
      else
        first_line
      end

    sep = String.duplicate("=", 80)
    sub_sep = String.duplicate("-", 80)
    section_sep = String.duplicate("~", 80)

    IO.puts("\n" <> sep)
    IO.puts("[Node #{node.id}] #{preview}")
    IO.puts("Mode: #{mode_label} (#{resolved_mode})")
    IO.puts(sub_sep)

    # Build question bodies with PromptBuilder, then wrap with context(s), then compose
    items =
      [
        {"Response",
         node
         |> context_for(graph_id)
         |> wrap_with(fn -> PromptBuilder.question_response(title) end)
         |> compose(resolved_mode)},
        {"Selection",
         if selection do
           node
           |> context_for(graph_id)
           |> wrap_with(fn ->
             selection
             |> PromptBuilder.question_selection()
             |> ensure_selection_header("Instruction (apply to the context and current node):")
           end)
           |> compose(resolved_mode)
         end},
        {"Synthesis",
         if other do
           c1 = context_for(node, graph_id)
           c2 = context_for(other, graph_id)

           body = PromptBuilder.question_synthesis(title, to_string(other.content || ""))
           wrap_dual_context(c1, c2, body) |> compose(resolved_mode)
         end},
        {"Thesis",
         node
         |> context_for(graph_id)
         |> wrap_with(fn -> PromptBuilder.question_thesis(title) end)
         |> compose(resolved_mode)},
        {"Antithesis",
         node
         |> context_for(graph_id)
         |> wrap_with(fn -> PromptBuilder.question_antithesis(title) end)
         |> compose(resolved_mode)},
        {"Related ideas",
         node
         |> context_for(graph_id)
         |> wrap_with(fn ->
           # Reuse the same title cleaning as gen_related_ideas/...
           cleaned_title =
             title
             |> String.replace("**", "")
             |> then(&(&1 |> String.split("\n") |> List.first() |> to_string()))
             |> String.replace(~r/^\s*[#]{1,6}\s*/u, "")
             |> String.replace(~r/^Title:\s*/i, "")
             |> String.trim()

           PromptBuilder.question_related_ideas(cleaned_title)
         end)
         |> compose(resolved_mode)},
        {"Deepdive",
         wrap_context(
           to_string(node.content || ""),
           PromptBuilder.question_deepdive(title)
         )
         |> compose(resolved_mode)}
      ]
      |> Enum.filter(fn {_label, prompt} -> is_binary(prompt) and prompt != "" end)

    Enum.each(items, fn {label, prompt} ->
      IO.puts("\n" <> section_sep)
      IO.puts(">>> " <> label)
      IO.puts(section_sep)
      IO.puts(prompt)
    end)

    IO.puts(sub_sep <> "\n")
    :ok
  end

  @doc """
  Iterate a list of nodes and print prompts for each across a set of modes.
  modes can be:
    - :all (default) to use Modes.order/0
    - a single mode atom or string
    - a list of atoms/strings
  """
  def print_prompts_for_nodes(nodes, graph_id, modes \\ :all, opts \\ []) do
    mode_list =
      case modes do
        :all -> Modes.order()
        nil -> Modes.order()
        list when is_list(list) -> Enum.map(list, &Modes.normalize_id/1)
        single -> [Modes.normalize_id(single)]
      end

    Enum.each(List.wrap(nodes), fn n ->
      Enum.each(mode_list, fn m ->
        print_all_prompts(n, graph_id, m, opts)
      end)
    end)

    :ok
  end

  # ------------------------------------------------------------------------------
  # Internal helpers
  # ------------------------------------------------------------------------------

  defp build_context(graph_id, node), do: GraphManager.build_context(graph_id, node)

  defp context_for(node, graph_id), do: build_context(graph_id, node)

  defp wrap_context(context, body) when is_binary(context) and is_binary(body) do
    """
    Context:
    #{context}

    #{body}
    """
  end

  defp wrap_dual_context(context1, context2, body) do
    """
    Context of first argument:
    #{context1}

    Context of second argument:
    #{context2}

    #{body}
    """
  end

  defp wrap_with(context, body_fun) when is_function(body_fun, 0) do
    wrap_context(context, body_fun.())
  end

  # Keep compatibility with prior selection header used in some tests
  defp ensure_selection_header(body, expected_header) when is_binary(body) do
    case String.starts_with?(body, "Instruction (apply to the selection below):") do
      true ->
        String.replace_prefix(
          body,
          "Instruction (apply to the selection below):",
          expected_header
        )

      false ->
        body
    end
  end
end
