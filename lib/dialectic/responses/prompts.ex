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

  defp citation_encouragement do
    """
    **Source references:** Where relevant, ground your response in primary sources. Quote key thinkers or texts directly using blockquotes (> ) when a passage is particularly illuminating. Attribute ideas to their originators with enough detail (author, work title) for the reader to explore further. Link to supportive material using inline links ([text](url)) when a stable, authoritative URL exists (e.g., Wikipedia, Stanford Encyclopedia of Philosophy, arXiv, DOI links). Prioritize quality references that genuinely strengthen your points over quantity.
    """
  end

  defp citation_encouragement_for_arguments do
    """
    **Source references:** Strengthen your argument by citing primary sources, empirical evidence, or authoritative texts. Use direct quotes (> ) from key works when they powerfully support or illustrate your reasoning. Attribute claims to specific thinkers or studies so the reader can evaluate the evidence. Where available, link to the referenced works or supporting material using inline links ([text](url)).
    """
  end

  defp citation_encouragement_for_deep_dive do
    """
    **Source references:** A deep dive benefits greatly from engagement with primary texts. Quote directly from foundational works, seminal papers, or authoritative sources using blockquotes (> ). Reference specific authors, titles, chapters, or studies. Where scholars or thinkers disagree, cite the specific works representing each position. Link to key references using inline links ([text](url)) — prefer stable, authoritative URLs such as DOI links, arXiv, Wikipedia, Stanford Encyclopedia of Philosophy, or official publisher pages.
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
      - Surprising or counterintuitive angles that challenge common assumptions
      - Deeper mechanisms or processes
      - Vivid real-world examples, case studies, or analogies that make the concept click
      - Unexpected connections to other fields or ideas
      - Different perspectives or frameworks, especially ones that create productive tension
      """,
      citation_encouragement(),
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

      **Your task:** Answer **#{sanitize_title(topic)}** in a way that sparks genuine curiosity.

      Include:
      1. A compelling opening — lead with a surprising fact, a counterintuitive insight, or a thought-provoking quote that reframes how the reader thinks about this topic
      2. A clear, substantive answer that rewards the reader's attention
      3. 2-3 provocative follow-up questions or related topics that make the reader want to explore further

      Build on the Foundation without repeating it.
      """,
      citation_encouragement()
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
      - Opening with what makes this concept fascinating, surprising, or important — why should someone care?
      - Defining what it is with vivid examples or analogies that make it click
      - Exploring different perspectives or frameworks, especially where thinkers disagree
      - Raising compelling questions or connections that invite further exploration

      While the Foundation provides context, focus on depth and breadth regarding THIS specific concept.
      """,
      citation_encouragement()
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

      **Your task:** Synthesize these positions by:
      1. First, vividly articulating the **tension** between them — where do they genuinely conflict, and why does that friction matter?
      2. Then, identifying surprising common ground or complementary insights that aren't immediately obvious
      3. Finally, forging a unified framework that integrates both perspectives into something neither could achieve alone

      Make the reader feel the intellectual stakes before you resolve them. Do not simply summarize — create something new from their integration.
      """,
      citation_encouragement()
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

      **Your task:** Build a compelling, persuasive argument **IN FAVOR OF** the ideas or claims within this selection.

      Provide:
      - A vivid opening that captures why this position deserves serious consideration
      - Concrete evidence, real-world examples, or empirical data that make the case viscerally convincing
      - Novel angles, analogies, or supporting frameworks the reader likely hasn't considered
      - Where possible, a powerful quote from a notable thinker that crystallizes the argument

      Focus specifically on supporting the selected text. Make the reader *feel* why this matters, not just understand it logically.
      """,
      citation_encouragement_for_arguments()
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

      **Your task:** Build a compelling, persuasive argument **IN FAVOR OF** this claim: **#{sanitize_title(claim)}**

      Provide:
      - A vivid opening that captures why this position deserves serious consideration
      - New concrete evidence, real-world examples, or empirical data not yet mentioned that make the case viscerally convincing
      - Novel angles, analogies, or supporting frameworks the reader likely hasn't considered
      - Where possible, a powerful quote from a notable thinker that crystallizes the argument

      Make the reader *feel* why this matters, not just understand it logically. Avoid simply restating points already made in the Foundation.
      """,
      citation_encouragement_for_arguments(),
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

      **Your task:** Build a compelling, persuasive argument **AGAINST** the ideas or claims within this selection.

      Provide:
      - An opening that exposes the most striking weakness, blind spot, or hidden assumption in this position
      - Concrete counterexamples, contradicting evidence, or real-world failures that undermine the claim
      - Alternative frameworks or thinkers who offer a fundamentally different view
      - Where possible, a sharp quote from a notable critic or contrarian thinker that captures the core objection

      Focus specifically on critiquing the selected text. Make the reader genuinely reconsider what they thought they knew.
      """,
      citation_encouragement_for_arguments()
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

      **Your task:** Build a compelling, persuasive argument **AGAINST** this claim: **#{sanitize_title(claim)}**

      Provide:
      - An opening that exposes the most striking weakness, blind spot, or hidden assumption in this position
      - New concrete counterexamples, contradicting evidence, or real-world failures not yet mentioned
      - Alternative frameworks or thinkers who offer a fundamentally different view
      - Where possible, a sharp quote from a notable critic or contrarian thinker that captures the core objection

      Make the reader genuinely reconsider what they thought they knew. Avoid simply restating points already made in the Foundation.
      """,
      citation_encouragement_for_arguments(),
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

      **Your task:** Identify 3-5 fascinating rabbit holes — adjacent topics, thinkers, or concepts that would electrify this exploration.

      For each suggestion:
      - Open with a one-line hook that makes the reader think "I need to know more about this"
      - Explain the surprising or non-obvious connection to the current topic
      - Describe what new dimension or unexpected insight it would unlock
      - Name a specific work, text, or primary source worth exploring, with a brief note on why it's compelling

      Prioritize suggestions that open genuinely NEW directions and create "aha" moments, not just variations on what's already been discussed.
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

      **Your task:** Identify 3-5 fascinating rabbit holes — adjacent topics, thinkers, or concepts specifically related to **#{sanitize_title(selection_text)}**.

      For each suggestion:
      - Open with a one-line hook that makes the reader think "I need to know more about this"
      - Explain the surprising or non-obvious connection to this specific concept
      - Describe what new dimension or unexpected insight it would unlock
      - Name a specific work, text, or primary source worth exploring, with a brief note on why it's compelling

      Prioritize suggestions that open genuinely NEW directions and create "aha" moments, not just variations on what's already been discussed.
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
      - Surprising or counterintuitive aspects that challenge common understanding of this concept
      - Adding technical depth, nuance, or complexity specific to this concept
      - Vivid real-world examples, case studies, or historical episodes that bring the concept to life
      - Active debates, unresolved tensions, or open questions among experts
      - Exploring implications, edge cases, or subtleties that most treatments overlook

      You may write at length (beyond normal 500-word limit). Focus on adding substantial new understanding.
      """,
      citation_encouragement_for_deep_dive()
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
      - Leading with the most surprising, counterintuitive, or commonly misunderstood aspect of this topic
      - Adding technical depth, nuance, or complexity
      - Using vivid real-world examples, case studies, or historical episodes that make abstract ideas tangible
      - Surfacing active debates, unresolved tensions, or open questions among experts
      - Exploring implications, edge cases, or subtleties that most treatments overlook

      You may write at length (beyond normal 500-word limit). Focus on adding substantial new understanding.
      """,
      citation_encouragement_for_deep_dive(),
      anti_repetition_footer()
    ])
  end
end
