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
    # Only include context if it's short enough; otherwise omit for maximum freedom
    if String.length(context_text) < 500 do
      """
      ### Foundation (for reference)

      ```text
      #{context_text}
      ```

      ↑ Background context. You may reference this but are not bound by it.
      """
    else
      # For longer contexts, skip it entirely to allow free exploration
      ""
    end
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
      A specific phrase was highlighted: **#{sanitize_title(selection_text)}**

      **Your task:** Treat this as a NEW exploration starting point. Explain this concept in depth, opening up new directions:
      - What is this concept and why does it matter?
      - Provide concrete examples or applications
      - Explore different perspectives or frameworks
      - Identify related concepts or questions worth exploring
      - Consider implications, edge cases, or nuances

      While the Foundation provides context, feel free to explore this concept in directions that may diverge from the original discussion. The goal is depth and breadth on THIS specific concept.
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
