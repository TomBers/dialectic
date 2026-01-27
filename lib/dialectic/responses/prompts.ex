defmodule Dialectic.Responses.Prompts do
  @moduledoc """
  Mode-agnostic task instruction templates for user messages.

  These functions generate the "instruction" portion of a chat that pairs with
  a mode-specific system prompt (e.g., `PromptsStructured.system_preamble/0`
  or `PromptsCreative.system_preamble/0`). By unifying task prompts here,
  only the system message varies across modes.

  Each public function returns a Markdown string (restricted CommonMark subset).

  ## Design Principles

  These prompts are designed for **graph-based exploration** where each response
  extends a conversation thread. To minimize repetition:

  1. Context is framed as "already covered territory"
  2. Instructions emphasize ADDING new insights
  3. Tasks are framed as continuations, not standalone answers
  """

  # Maximum character length for context in minimal context prompts.
  # Longer contexts are truncated to this length to keep prompts focused
  # while still providing grounding from the immediate parent node.
  # This ensures consistent behavior regardless of parent node length.
  @minimal_context_max_length 1000

  # ---- Helpers ---------------------------------------------------------------

  defp frame_context(context_text) do
    """
    ### Foundation

    The following has already been explored:

    ```text
    #{context_text}
    ```

    ↑ This is already covered. Your response should ADD NEW insights beyond what's shown above.
    """
  end

  defp frame_minimal_context(context_text) do
    # Always include immediate parent context, truncating if needed
    # This provides consistent grounding regardless of parent length
    truncated_context =
      if String.length(context_text) > @minimal_context_max_length do
        String.slice(context_text, 0, @minimal_context_max_length) <>
          "\n\n[... truncated for brevity ...]"
      else
        context_text
      end

    """
    ### Foundation (for reference)

    ```text
    #{truncated_context}
    ```

    ↑ Background context. You may reference this but are not bound by it.
    """
  end

  defp join_blocks(blocks) do
    blocks
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.join("\n\n")
  end

  defp sanitize_title(title) do
    s = to_string(title) |> String.trim()
    Regex.replace(~r/^\s*#+\s*/, s, "")
  end

  defp anti_repetition_footer do
    """
    **Important:** Do not repeat or merely rephrase what's in the Foundation section. Focus on adding genuinely new information, perspectives, or insights.
    """
  end

  # ---- Templates -------------------------------------------------------------

  @doc """
  Explain a topic to a motivated learner, grounded in prior context.
  """
  @spec explain(String.t(), String.t()) :: String.t()
  def explain(context, topic) do
    join_blocks([
      frame_context(context),
      """
      You are continuing an exploration where the Foundation has already been covered.

      **Your task:** Explain **#{sanitize_title(topic)}** by ADDING new perspectives, details, or insights that EXTEND BEYOND what's already in the Foundation.

      Focus on aspects not yet discussed, such as:
      - Deeper mechanisms or processes
      - Concrete examples or applications
      - Different perspectives or frameworks
      - Connections to related concepts
      """,
      anti_repetition_footer()
    ])
  end

  @doc """
  Initial answer to a question, with suggestions for further exploration.
  """
  @spec initial_explainer(String.t(), String.t()) :: String.t()
  def initial_explainer(context, topic) do
    join_blocks([
      frame_context(context),
      """
      You are beginning an exploration. The Foundation provides background.

      **Your task:** Answer **#{sanitize_title(topic)}** while identifying promising directions for deeper exploration.

      Include:
      1. A clear, substantive answer
      2. 2-3 extension questions or related topics that would enrich understanding

      Build on the Foundation without repeating it.
      """
    ])
  end

  @doc """
  Apply an instruction or selection to the current context.
  """
  @spec selection(String.t(), String.t()) :: String.t()
  def selection(context, selection_text) do
    join_blocks([
      frame_minimal_context(context),
      """
      A specific topic was highlighted from the text above: **#{sanitize_title(selection_text)}**

      **Your task:** Explain **#{sanitize_title(selection_text)}** in depth, treating it as a new exploration starting point.

      Focus on:
      - Defining what this concept is and why it matters
      - Providing concrete examples or applications
      - Exploring different perspectives or frameworks
      - Identifying related concepts or questions worth exploring

      While the Foundation provides context, focus on depth and breadth regarding THIS specific concept.
      """
    ])
  end

  @doc """
  Synthesize two positions with their contexts.
  """
  @spec synthesis(String.t(), String.t(), String.t(), String.t()) :: String.t()
  def synthesis(context1, context2, pos1, pos2) do
    join_blocks([
      """
      ### Foundation A
      ```text
      #{context1}
      ```

      ### Foundation B
      ```text
      #{context2}
      ```
      """,
      """
      Two different lines of inquiry have emerged:

      **Position A:** #{sanitize_title(pos1)}
      **Position B:** #{sanitize_title(pos2)}

      **Your task:** Synthesize these positions by identifying:
      - Common ground or complementary insights
      - A unified framework that integrates both perspectives
      - New understanding that emerges from their combination

      Do not simply summarize—create something new from their integration.
      """
    ])
  end

  @doc """
  Present reasons in favor of a selected claim/concept.
  """
  @spec thesis_selection(String.t(), String.t()) :: String.t()
  def thesis_selection(context, selection_text) do
    join_blocks([
      frame_minimal_context(context),
      """
      A specific statement or concept was highlighted from the text above: **#{sanitize_title(selection_text)}**

      **Your task:** Build a strong argument **IN FAVOR OF** the ideas or claims within this selection.

      Provide:
      - Reasoning, evidence, or examples supporting this selection
      - Novel angles or supporting frameworks
      - Fresh perspectives that strengthen the case

      Focus specifically on supporting the selected text.
      """
    ])
  end

  @doc """
  Present reasons in favor of a claim, grounded in context.
  """
  @spec thesis(String.t(), String.t()) :: String.t()
  def thesis(context, claim) do
    join_blocks([
      frame_context(context),
      """
      The Foundation represents existing discussion.

      **Your task:** Build a strong argument **IN FAVOR OF** this claim: **#{sanitize_title(claim)}**

      Provide:
      - New reasoning, evidence, or examples not yet mentioned
      - Novel angles or supporting frameworks
      - Fresh perspectives that strengthen the case

      Avoid simply restating points already made in the Foundation.
      """,
      anti_repetition_footer()
    ])
  end

  @doc """
  Present reasons against a selected claim/concept.
  """
  @spec antithesis_selection(String.t(), String.t()) :: String.t()
  def antithesis_selection(context, selection_text) do
    join_blocks([
      frame_minimal_context(context),
      """
      A specific statement or concept was highlighted from the text above: **#{sanitize_title(selection_text)}**

      **Your task:** Build a strong argument **AGAINST** the ideas or claims within this selection.

      Provide:
      - Counterarguments, contradicting evidence, or counterexamples
      - Alternative frameworks that challenge the selection
      - Critical perspectives

      Focus specifically on critiquing the selected text.
      """
    ])
  end

  @doc """
  Present reasons against a claim, grounded in context.
  """
  @spec antithesis(String.t(), String.t()) :: String.t()
  def antithesis(context, claim) do
    join_blocks([
      frame_context(context),
      """
      The Foundation represents existing discussion.

      **Your task:** Build a strong argument **AGAINST** this claim: **#{sanitize_title(claim)}**

      Provide:
      - New counterarguments, contradicting evidence, or counterexamples
      - Alternative frameworks that challenge the claim
      - Fresh critical perspectives not yet explored

      Avoid simply restating points already made in the Foundation.
      """,
      anti_repetition_footer()
    ])
  end

  @doc """
  Suggest adjacent topics or thinkers grounded in context.
  """
  @spec related_ideas(String.t(), String.t()) :: String.t()
  def related_ideas(context, current_idea_title) do
    join_blocks([
      frame_context(context),
      """
      The exploration has covered: **#{sanitize_title(current_idea_title)}**

      **Your task:** Identify 3-5 adjacent topics, thinkers, or concepts that would enrich this exploration.

      For each suggestion, briefly explain:
      - How it connects to the current topic
      - What new dimension it would add to understanding

      Prioritize suggestions that open NEW directions, not just variations on what's already been discussed.
      """
    ])
  end

  @doc """
  Suggest adjacent topics or thinkers based on a specific text selection within context.
  """
  @spec related_ideas_selection(String.t(), String.t()) :: String.t()
  def related_ideas_selection(context, selection_text) do
    join_blocks([
      frame_minimal_context(context),
      """
      A specific topic was highlighted from the text above: **#{sanitize_title(selection_text)}**

      **Your task:** Identify 3-5 adjacent topics, thinkers, or concepts specifically related to **#{sanitize_title(selection_text)}**.

      For each suggestion, briefly explain:
      - How it connects to this specific concept
      - What new dimension it would add to understanding

      Prioritize suggestions that open NEW directions, not just variations on what's already been discussed.
      """
    ])
  end

  @doc """
  Provide a deeper exploration of a specific text selection.
  """
  @spec deep_dive_selection(String.t(), String.t()) :: String.t()
  def deep_dive_selection(context, selection_text) do
    join_blocks([
      frame_minimal_context(context),
      """
      A specific topic was highlighted from the text above: **#{sanitize_title(selection_text)}**

      **Your task:** Write a deep dive specifically on **#{sanitize_title(selection_text)}** that goes significantly deeper than the context provided.

      Focus on:
      - Adding technical depth, nuance, or complexity specific to this concept
      - Providing concrete examples, case studies, or applications
      - Exploring implications, edge cases, or subtleties
      - Addressing questions the context raises but doesn't answer

      You may write at length (beyond normal 500-word limit). Focus on adding substantial new understanding.
      """
    ])
  end

  @doc """
  Provide a deeper exploration of a topic for advanced learners.
  """
  @spec deep_dive(String.t(), String.t()) :: String.t()
  def deep_dive(context, topic) do
    join_blocks([
      frame_context(context),
      """
      The Foundation provides an overview of **#{sanitize_title(topic)}**.

      **Your task:** Write a deep dive that goes BEYOND the overview by:
      - Adding technical depth, nuance, or complexity
      - Providing concrete examples, case studies, or applications
      - Exploring implications, edge cases, or subtleties
      - Addressing questions the overview raises but doesn't answer

      You may write at length (beyond normal 500-word limit). Focus on adding substantial new understanding.
      """,
      anti_repetition_footer()
    ])
  end
end
