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

  # ---- Cluster 1: Core Inquiry Moves -----------------------------------------

  @doc """
  Conceptual clarification — "What do you mean by…?"
  Identifies how key terms are being used and surfaces ambiguity.
  """
  @spec clarify(String.t(), String.t()) :: String.t()
  def clarify(context, claim) do
    join_blocks([
      frame_context(context),
      """
      The Foundation represents existing discussion.

      **Your task:** Perform conceptual clarification on: **#{sanitize_title(claim)}**

      Examine this claim through the lens of "What do you mean by...?" — the most fundamental move in philosophical inquiry. Focus on:

      - **Key terms:** Identify 2-4 terms or phrases that carry significant conceptual weight. For each, explore: How is it being used here? What alternative definitions exist? What does each definition include or exclude?
      - **Hidden ambiguities:** Surface places where the same word might be doing double duty, or where vagueness masks important distinctions
      - **Conceptual boundaries:** Where does this concept end and neighboring concepts begin? What's the difference between this and closely related ideas?
      - **Operational definitions:** How would we actually recognize or measure what's being claimed? What would count as evidence?
      - **Stipulative vs. descriptive:** Is the claim defining terms a certain way (stipulative) or describing how they're actually used (descriptive)? Does this matter for evaluating the claim?

      The goal is not to attack the claim but to sharpen it — to transform fuzzy intuitions into precise propositions that can be properly evaluated.
      """,
      citation_encouragement(),
      anti_repetition_footer()
    ])
  end

  @doc """
  Conceptual clarification for a specific text selection.
  """
  @spec clarify_selection(String.t(), String.t()) :: String.t()
  def clarify_selection(context, selection_text) do
    join_blocks([
      frame_minimal_context(context),
      """
      A specific statement or concept was highlighted from the text above: **#{sanitize_title(selection_text)}**

      **Your task:** Perform conceptual clarification — ask "What do you mean by...?" of this selection.

      Focus on:
      - **Key terms:** Identify 2-4 terms or phrases that carry significant conceptual weight. For each, explore: How is it being used here? What alternative definitions exist? What does each definition include or exclude?
      - **Hidden ambiguities:** Surface places where the same word might be doing double duty, or where vagueness masks important distinctions
      - **Conceptual boundaries:** Where does this concept end and neighboring concepts begin? What's the difference between this and closely related ideas?
      - **Operational definitions:** How would we actually recognize or measure what's being claimed? What would count as evidence?
      - **Stipulative vs. descriptive:** Is the claim defining terms a certain way or describing how they're actually used?

      The goal is not to attack the selection but to sharpen it — to transform fuzzy intuitions into precise propositions that can be properly evaluated.
      """,
      citation_encouragement()
    ])
  end

  @doc """
  Surface hidden premises — "What has to be true?"
  Excavates the factual, value, conceptual, and logical assumptions underlying a claim.
  """
  @spec assumptions(String.t(), String.t()) :: String.t()
  def assumptions(context, claim) do
    join_blocks([
      frame_context(context),
      """
      The Foundation represents existing discussion.

      **Your task:** Surface the hidden premises underlying: **#{sanitize_title(claim)}**

      Ask "What has to be true for this claim to hold?" Excavate assumptions across multiple dimensions:

      - **Factual assumptions:** What empirical claims does this argument take for granted? What would have to be true about the world?
      - **Value assumptions:** What must we value, prioritize, or consider important? What ethical or aesthetic commitments are smuggled in?
      - **Conceptual assumptions:** What definitions, categories, or frameworks are assumed? What conceptual scheme makes this claim intelligible?
      - **Logical assumptions:** What inferential leaps occur? What causal claims are embedded? What's the assumed relationship between premises and conclusion?
      - **Contextual assumptions:** What historical, cultural, or situational factors are taken as given? Who is the assumed audience?

      For each assumption you surface:
      1. State it explicitly
      2. Assess how controversial or contestable it is
      3. Note what happens to the argument if this assumption is challenged

      The goal is to make the invisible scaffolding visible — to show what the claim is secretly standing on.
      """,
      citation_encouragement(),
      anti_repetition_footer()
    ])
  end

  @doc """
  Surface hidden premises for a specific text selection.
  """
  @spec assumptions_selection(String.t(), String.t()) :: String.t()
  def assumptions_selection(context, selection_text) do
    join_blocks([
      frame_minimal_context(context),
      """
      A specific statement or concept was highlighted from the text above: **#{sanitize_title(selection_text)}**

      **Your task:** Surface the hidden premises underlying this selection — ask "What has to be true?"

      Excavate assumptions across multiple dimensions:
      - **Factual assumptions:** What empirical claims does this take for granted? What would have to be true about the world?
      - **Value assumptions:** What must we value, prioritize, or consider important? What ethical commitments are smuggled in?
      - **Conceptual assumptions:** What definitions, categories, or frameworks are assumed? What conceptual scheme makes this intelligible?
      - **Logical assumptions:** What inferential leaps occur? What causal claims are embedded?
      - **Contextual assumptions:** What historical, cultural, or situational factors are taken as given?

      For each assumption you surface:
      1. State it explicitly
      2. Assess how controversial or contestable it is
      3. Note what happens to the argument if this assumption is challenged

      The goal is to make the invisible scaffolding visible — to show what this claim is secretly standing on.
      """,
      citation_encouragement()
    ])
  end

  @doc """
  Find counterexamples — "Is that always true?"
  Identifies direct counterexamples, edge cases, and domain boundaries.
  """
  @spec counterexample(String.t(), String.t()) :: String.t()
  def counterexample(context, claim) do
    join_blocks([
      frame_context(context),
      """
      The Foundation represents existing discussion.

      **Your task:** Test the boundaries of: **#{sanitize_title(claim)}**

      Ask "Is that always true?" and hunt for cases where it breaks down:

      - **Direct counterexamples:** Find concrete, real-world cases where the claim demonstrably fails. Historical examples, documented cases, or well-known instances carry special weight.
      - **Edge cases:** Explore boundary conditions. What happens at extremes? In unusual circumstances? When variables are pushed to their limits?
      - **Domain boundaries:** Where does this claim apply and where does it not? What's the scope of validity? Are there entire contexts where it doesn't hold?
      - **Thought experiments:** Construct hypothetical scenarios that test the claim's limits. What minimal changes would break it?
      - **Category errors:** Are there types of cases that seem relevant but where the claim simply doesn't apply? Why not?

      For each counterexample:
      1. Describe it vividly and specifically
      2. Explain why it constitutes a genuine challenge (not just an exception that proves the rule)
      3. Assess whether it refutes the claim entirely, restricts its scope, or reveals needed qualifications

      The goal is rigorous stress-testing — finding the cracks before committing to the claim.
      """,
      citation_encouragement(),
      anti_repetition_footer()
    ])
  end

  @doc """
  Find counterexamples for a specific text selection.
  """
  @spec counterexample_selection(String.t(), String.t()) :: String.t()
  def counterexample_selection(context, selection_text) do
    join_blocks([
      frame_minimal_context(context),
      """
      A specific statement or concept was highlighted from the text above: **#{sanitize_title(selection_text)}**

      **Your task:** Test the boundaries of this selection — ask "Is that always true?"

      Hunt for cases where it breaks down:
      - **Direct counterexamples:** Find concrete, real-world cases where this demonstrably fails. Historical examples, documented cases, or well-known instances carry special weight.
      - **Edge cases:** Explore boundary conditions. What happens at extremes? In unusual circumstances?
      - **Domain boundaries:** Where does this apply and where does it not? What's the scope of validity?
      - **Thought experiments:** Construct hypothetical scenarios that test the limits. What minimal changes would break it?
      - **Category errors:** Are there types of cases that seem relevant but where this simply doesn't apply?

      For each counterexample:
      1. Describe it vividly and specifically
      2. Explain why it constitutes a genuine challenge
      3. Assess whether it refutes the claim entirely, restricts its scope, or reveals needed qualifications

      The goal is rigorous stress-testing — finding the cracks before committing to the claim.
      """,
      citation_encouragement()
    ])
  end

  @doc """
  Trace implications — "So what?"
  Explores immediate, practical, conceptual, and uncomfortable consequences.
  """
  @spec implications(String.t(), String.t()) :: String.t()
  def implications(context, claim) do
    join_blocks([
      frame_context(context),
      """
      The Foundation represents existing discussion.

      **Your task:** Trace the implications of: **#{sanitize_title(claim)}**

      Ask "So what?" and follow the consequences relentlessly:

      - **Immediate implications:** If this is true, what else must be true? What follows directly and necessarily?
      - **Practical implications:** What should we DO differently if this is correct? How would it change decisions, policies, or behaviors?
      - **Conceptual implications:** What other beliefs or frameworks need revision? What becomes inconsistent with our existing commitments?
      - **Uncomfortable implications:** What follows that we might not want to accept? Does this lead to conclusions that seem absurd, immoral, or counterintuitive (reductio ad absurdum)?
      - **Second-order effects:** If people widely adopted this view, what would the downstream consequences be? What feedback loops might emerge?
      - **Existential implications:** What does this mean for how we should live, what we should value, or who we should become?

      Be thorough and unflinching. The test of a belief is whether we can accept where it leads. Surface implications the original claim might prefer to hide from.
      """,
      citation_encouragement(),
      anti_repetition_footer()
    ])
  end

  @doc """
  Trace implications for a specific text selection.
  """
  @spec implications_selection(String.t(), String.t()) :: String.t()
  def implications_selection(context, selection_text) do
    join_blocks([
      frame_minimal_context(context),
      """
      A specific statement or concept was highlighted from the text above: **#{sanitize_title(selection_text)}**

      **Your task:** Trace the implications of this selection — ask "So what?"

      Follow the consequences relentlessly:
      - **Immediate implications:** If this is true, what else must be true? What follows directly and necessarily?
      - **Practical implications:** What should we DO differently if this is correct? How would it change decisions or behaviors?
      - **Conceptual implications:** What other beliefs or frameworks need revision? What becomes inconsistent?
      - **Uncomfortable implications:** What follows that we might not want to accept? Does this lead to absurd or counterintuitive conclusions?
      - **Second-order effects:** If people widely adopted this view, what would the downstream consequences be?
      - **Existential implications:** What does this mean for how we should live or what we should value?

      Be thorough and unflinching. The test of a belief is whether we can accept where it leads. Surface implications the original claim might prefer to hide from.
      """,
      citation_encouragement()
    ])
  end

  @doc """
  Identify blind spots — "What's missing?"
  Surfaces missing perspectives, evidence, questions, context, and excluded alternatives.
  """
  @spec blind_spots(String.t(), String.t()) :: String.t()
  def blind_spots(context, claim) do
    join_blocks([
      frame_context(context),
      """
      The Foundation represents existing discussion.

      **Your task:** Identify the blind spots in: **#{sanitize_title(claim)}**

      Ask "What's missing?" and illuminate what remains unseen:

      - **Missing perspectives:** Whose voices, experiences, or viewpoints are absent? Who would see this differently? What would this look like from another culture, time period, discipline, or social position?
      - **Missing evidence:** What data, research, or empirical investigation would help? What questions remain unanswered? What would we need to know to be more confident?
      - **Missing questions:** What obvious questions does this fail to ask? What elephants are in the room? What's conspicuously unaddressed?
      - **Missing context:** What historical, cultural, economic, or situational factors are ignored? What background conditions matter but aren't mentioned?
      - **Excluded alternatives:** What options, explanations, or possibilities are implicitly ruled out? What's been assumed away rather than argued against?
      - **Structural blind spots:** What can't this framework see by its very nature? What are the built-in limitations of this way of thinking?

      For each blind spot:
      1. Identify it specifically
      2. Explain why it matters — what might change if we addressed it
      3. Suggest how it might be remedied

      The goal is not to attack but to complete — to see what the claim cannot see about itself.
      """,
      citation_encouragement(),
      anti_repetition_footer()
    ])
  end

  @doc """
  Identify blind spots for a specific text selection.
  """
  @spec blind_spots_selection(String.t(), String.t()) :: String.t()
  def blind_spots_selection(context, selection_text) do
    join_blocks([
      frame_minimal_context(context),
      """
      A specific statement or concept was highlighted from the text above: **#{sanitize_title(selection_text)}**

      **Your task:** Identify the blind spots in this selection — ask "What's missing?"

      Illuminate what remains unseen:
      - **Missing perspectives:** Whose voices or viewpoints are absent? Who would see this differently?
      - **Missing evidence:** What data or research would help? What questions remain unanswered?
      - **Missing questions:** What obvious questions does this fail to ask? What's conspicuously unaddressed?
      - **Missing context:** What historical, cultural, or situational factors are ignored?
      - **Excluded alternatives:** What options or explanations are implicitly ruled out?
      - **Structural blind spots:** What can't this framework see by its very nature?

      For each blind spot:
      1. Identify it specifically
      2. Explain why it matters — what might change if we addressed it
      3. Suggest how it might be remedied

      The goal is not to attack but to complete — to see what the claim cannot see about itself.
      """,
      citation_encouragement()
    ])
  end

  # ---- Cluster 2: Context & Dialectical Expansion ----------------------------

  @doc """
  Examine origin and authority — "Says who?"
  Investigates the source, evidence base, methodology, and credibility of claims.
  """
  @spec says_who(String.t(), String.t()) :: String.t()
  def says_who(context, claim) do
    join_blocks([
      frame_context(context),
      """
      The Foundation represents existing discussion.

      **Your task:** Examine the origin and authority behind: **#{sanitize_title(claim)}**

      Ask "Says who?" and investigate the foundations of credibility:

      - **Origin:** Where does this claim come from? Who first articulated it? In what context did it emerge? What motivated its creation?
      - **Evidence base:** What evidence supports this claim? How strong is it? What methodology produced it? Has it been replicated, peer-reviewed, or independently verified?
      - **Authority:** Who endorses this view? What are their credentials, potential biases, or conflicts of interest? Is this mainstream or fringe within relevant expert communities?
      - **Track record:** How have similar claims from this source held up over time? What's the credibility history?
      - **Counter-authorities:** Who with comparable credentials disagrees? What do they say and why? Is there genuine expert disagreement?
      - **Institutional context:** What institutions, funding sources, or power structures support this claim? Whose interests does it serve?
      - **Epistemic status:** Is this presented as established fact, scientific consensus, expert opinion, educated guess, or speculation? Is that presentation warranted?

      The goal is not cynical dismissal but calibrated trust — understanding how much weight this claim should carry and why.
      """,
      citation_encouragement(),
      anti_repetition_footer()
    ])
  end

  @doc """
  Examine origin and authority for a specific text selection.
  """
  @spec says_who_selection(String.t(), String.t()) :: String.t()
  def says_who_selection(context, selection_text) do
    join_blocks([
      frame_minimal_context(context),
      """
      A specific statement or concept was highlighted from the text above: **#{sanitize_title(selection_text)}**

      **Your task:** Examine the origin and authority behind this selection — ask "Says who?"

      Investigate the foundations of credibility:
      - **Origin:** Where does this claim come from? Who first articulated it? In what context did it emerge?
      - **Evidence base:** What evidence supports this? How strong is it? What methodology produced it?
      - **Authority:** Who endorses this view? What are their credentials, potential biases, or conflicts of interest?
      - **Track record:** How have similar claims from this source held up over time?
      - **Counter-authorities:** Who with comparable credentials disagrees? What do they say?
      - **Institutional context:** What institutions or power structures support this claim? Whose interests does it serve?
      - **Epistemic status:** Is this established fact, consensus, expert opinion, or speculation? Is that warranted?

      The goal is not cynical dismissal but calibrated trust — understanding how much weight this claim should carry.
      """,
      citation_encouragement()
    ])
  end

  @doc """
  Map the landscape of dissent — "Who disagrees?"
  Surveys alternative positions, schools of thought, and the full range of disagreement.
  """
  @spec who_disagrees(String.t(), String.t()) :: String.t()
  def who_disagrees(context, claim) do
    join_blocks([
      frame_context(context),
      """
      The Foundation represents existing discussion.

      **Your task:** Map the landscape of dissent around: **#{sanitize_title(claim)}**

      Ask "Who disagrees?" and survey the full range of opposition:

      - **Named critics:** Identify specific thinkers, scholars, or public figures who have argued against this position. What are their main objections? Where can their critiques be found?
      - **Schools of thought:** What intellectual traditions, disciplines, or ideological camps take opposing views? How do their alternative frameworks lead to different conclusions?
      - **Types of disagreement:** Distinguish between those who reject the premise entirely, those who accept the premise but dispute the conclusion, and those who think the question itself is malformed.
      - **Strength of objections:** Which critiques are most powerful? Which have the most empirical or logical force? Which remain largely unanswered?
      - **Historical evolution:** How has opposition evolved over time? Have critics been refuted, vindicated, or ignored?
      - **Current debates:** Where are the live controversies? What's actively contested versus settled?
      - **Unusual alliances:** Are there surprising combinations of thinkers who agree in opposing this? What does that tell us?

      Present the disagreement fairly. The goal is intellectual cartography — a map of the contested terrain, not a verdict.
      """,
      citation_encouragement(),
      anti_repetition_footer()
    ])
  end

  @doc """
  Map the landscape of dissent for a specific text selection.
  """
  @spec who_disagrees_selection(String.t(), String.t()) :: String.t()
  def who_disagrees_selection(context, selection_text) do
    join_blocks([
      frame_minimal_context(context),
      """
      A specific statement or concept was highlighted from the text above: **#{sanitize_title(selection_text)}**

      **Your task:** Map the landscape of dissent around this selection — ask "Who disagrees?"

      Survey the full range of opposition:
      - **Named critics:** Identify specific thinkers or scholars who have argued against this. What are their main objections?
      - **Schools of thought:** What intellectual traditions or disciplines take opposing views?
      - **Types of disagreement:** Who rejects the premise? Who disputes the conclusion? Who thinks the question is malformed?
      - **Strength of objections:** Which critiques are most powerful? Which remain largely unanswered?
      - **Historical evolution:** How has opposition evolved over time?
      - **Current debates:** Where are the live controversies? What's actively contested?
      - **Unusual alliances:** Are there surprising combinations of critics? What does that suggest?

      Present the disagreement fairly. The goal is intellectual cartography — a map of the contested terrain, not a verdict.
      """,
      citation_encouragement()
    ])
  end

  @doc """
  Surface analogies — "What is this like?"
  Finds illuminating parallels from different domains, eras, or fields.
  """
  @spec analogy(String.t(), String.t()) :: String.t()
  def analogy(context, claim) do
    join_blocks([
      frame_context(context),
      """
      The Foundation represents existing discussion.

      **Your task:** Surface illuminating analogies for: **#{sanitize_title(claim)}**

      Ask "What is this like?" and find revealing parallels:

      - **Cross-domain analogies:** What phenomena in completely different fields share deep structural similarities? Look across science, art, history, nature, technology, and everyday life.
      - **Historical parallels:** What past situations, debates, or transitions resemble this? What can we learn from how they unfolded?
      - **Scale shifts:** What happens if we imagine this at much larger or smaller scales? Does the logic still hold?
      - **Perspective shifts:** How might different professions, cultures, or disciplines frame this as an instance of patterns they recognize?
      - **Metaphors in use:** What metaphors are already embedded in how we talk about this? Are they helping or hindering understanding?
      - **Disanalogies that illuminate:** Where do seemingly apt comparisons break down? What do the differences reveal?

      For each strong analogy:
      1. Describe the parallel vividly
      2. Explain what structural features map onto each other
      3. Note what the analogy illuminates that direct analysis might miss
      4. Acknowledge where the analogy breaks down and what that teaches us

      Great analogies don't just illustrate — they generate new insight by revealing hidden structure.
      """,
      citation_encouragement(),
      anti_repetition_footer()
    ])
  end

  @doc """
  Surface analogies for a specific text selection.
  """
  @spec analogy_selection(String.t(), String.t()) :: String.t()
  def analogy_selection(context, selection_text) do
    join_blocks([
      frame_minimal_context(context),
      """
      A specific statement or concept was highlighted from the text above: **#{sanitize_title(selection_text)}**

      **Your task:** Surface illuminating analogies for this selection — ask "What is this like?"

      Find revealing parallels:
      - **Cross-domain analogies:** What phenomena in completely different fields share deep structural similarities?
      - **Historical parallels:** What past situations, debates, or transitions resemble this?
      - **Scale shifts:** What happens if we imagine this at much larger or smaller scales?
      - **Perspective shifts:** How might different disciplines frame this as an instance of patterns they recognize?
      - **Metaphors in use:** What metaphors are already embedded here? Are they helping or hindering?
      - **Disanalogies that illuminate:** Where do seemingly apt comparisons break down?

      For each strong analogy:
      1. Describe the parallel vividly
      2. Explain what structural features map onto each other
      3. Note what the analogy illuminates that direct analysis might miss
      4. Acknowledge where the analogy breaks down and what that teaches us

      Great analogies don't just illustrate — they generate new insight by revealing hidden structure.
      """,
      citation_encouragement()
    ])
  end

  @doc """
  Construct the strongest version — Steel man the argument.
  Builds the most charitable, powerful form of the position.
  """
  @spec steel_man(String.t(), String.t()) :: String.t()
  def steel_man(context, claim) do
    join_blocks([
      frame_context(context),
      """
      The Foundation represents existing discussion.

      **Your task:** Construct the strongest possible version of: **#{sanitize_title(claim)}**

      Steel-man this position by building the argument a brilliant, well-informed advocate would make:

      - **Charitable interpretation:** Start from the most reasonable, defensible reading. What's the strongest version of what's being claimed?
      - **Better arguments:** What arguments support this position that weren't mentioned? What's the best case, not just the stated case?
      - **Strongest evidence:** What data, studies, examples, or precedents most powerfully support this view? Include evidence the original argument may have missed.
      - **Addressing weaknesses:** Anticipate the strongest objections and show how a sophisticated defender would respond. Don't ignore problems — resolve them.
      - **Deeper foundations:** What philosophical, empirical, or logical principles undergird this position when fully developed?
      - **Formidable advocates:** Who are the most impressive thinkers who hold versions of this view? What do their sophisticated versions look like?

      The goal is to make this position as strong as it can possibly be — to understand what you'd be taking on if you disagreed. Only after steel-manning can criticism be truly meaningful.
      """,
      citation_encouragement_for_arguments(),
      anti_repetition_footer()
    ])
  end

  @doc """
  Construct the strongest version for a specific text selection.
  """
  @spec steel_man_selection(String.t(), String.t()) :: String.t()
  def steel_man_selection(context, selection_text) do
    join_blocks([
      frame_minimal_context(context),
      """
      A specific statement or concept was highlighted from the text above: **#{sanitize_title(selection_text)}**

      **Your task:** Construct the strongest possible version of this selection — steel-man the argument.

      Build the case a brilliant, well-informed advocate would make:
      - **Charitable interpretation:** What's the strongest version of what's being claimed?
      - **Better arguments:** What arguments support this position that weren't mentioned?
      - **Strongest evidence:** What data, studies, or examples most powerfully support this view?
      - **Addressing weaknesses:** How would a sophisticated defender respond to the strongest objections?
      - **Deeper foundations:** What philosophical or logical principles undergird this position when fully developed?
      - **Formidable advocates:** Who are the most impressive thinkers who hold versions of this view?

      The goal is to make this position as strong as it can possibly be. Only after steel-manning can criticism be truly meaningful.
      """,
      citation_encouragement_for_arguments()
    ])
  end

  @doc """
  Explore counterfactuals — "What if we change X?"
  Investigates how the claim changes under different conditions or assumptions.
  """
  @spec what_if(String.t(), String.t()) :: String.t()
  def what_if(context, claim) do
    join_blocks([
      frame_context(context),
      """
      The Foundation represents existing discussion.

      **Your task:** Explore counterfactuals around: **#{sanitize_title(claim)}**

      Ask "What if we change X?" and investigate how the claim transforms:

      - **Parameter variation:** What if key quantities, timeframes, or magnitudes were different? Where are the thresholds that change the conclusion?
      - **Assumption reversal:** What if we flip core assumptions? If the opposite were true, what would follow?
      - **Context shifts:** What if this occurred in a different era, culture, economic system, or technological context? How robust is the claim across contexts?
      - **Actor substitution:** What if different people, groups, or entities were involved? How sensitive is the claim to who's doing what?
      - **Missing factor introduction:** What if we add considerations that were excluded? What external shocks or new variables would change the picture?
      - **Historical counterfactuals:** What if key events had gone differently? What does the road not taken reveal about necessity vs. contingency?
      - **Future scenarios:** Under what future conditions does this claim become more or less true?

      For each illuminating counterfactual:
      1. Specify the change clearly
      2. Trace through the consequences
      3. Identify what this reveals about the original claim's robustness or fragility

      Counterfactual reasoning reveals what's essential versus accidental, and exposes hidden dependencies.
      """,
      citation_encouragement(),
      anti_repetition_footer()
    ])
  end

  @doc """
  Explore counterfactuals for a specific text selection.
  """
  @spec what_if_selection(String.t(), String.t()) :: String.t()
  def what_if_selection(context, selection_text) do
    join_blocks([
      frame_minimal_context(context),
      """
      A specific statement or concept was highlighted from the text above: **#{sanitize_title(selection_text)}**

      **Your task:** Explore counterfactuals around this selection — ask "What if we change X?"

      Investigate how the claim transforms:
      - **Parameter variation:** What if key quantities or timeframes were different? Where are the thresholds?
      - **Assumption reversal:** What if we flip core assumptions? What would follow?
      - **Context shifts:** What if this occurred in a different era, culture, or technological context?
      - **Actor substitution:** What if different people or groups were involved?
      - **Missing factor introduction:** What if we add considerations that were excluded?
      - **Historical counterfactuals:** What if key events had gone differently?
      - **Future scenarios:** Under what future conditions does this become more or less true?

      For each illuminating counterfactual:
      1. Specify the change clearly
      2. Trace through the consequences
      3. Identify what this reveals about the original claim's robustness or fragility

      Counterfactual reasoning reveals what's essential versus accidental, and exposes hidden dependencies.
      """,
      citation_encouragement()
    ])
  end

  # ---- Cluster 3: Clarity & Communication ------------------------------------

  @doc """
  Simplify for accessibility — Make complex ideas clear.
  Translates sophisticated content for a general audience without losing substance.
  """
  @spec simplify(String.t(), String.t()) :: String.t()
  def simplify(context, claim) do
    join_blocks([
      frame_context(context),
      """
      The Foundation represents existing discussion.

      **Your task:** Make this accessible to a general audience: **#{sanitize_title(claim)}**

      Simplify without dumbing down:

      - **Core insight first:** Lead with the central point in plain language. What's the one thing someone should take away?
      - **Jargon translation:** Replace technical terms with everyday language, or explain them with vivid analogies when the term itself matters
      - **Concrete examples:** Ground abstractions in tangible, relatable scenarios. Use examples from everyday life that most people can connect with.
      - **Progressive complexity:** Start simple, then add nuance. Let readers go as deep as they want.
      - **Visual thinking:** Use spatial metaphors, comparisons to familiar objects, or "imagine..." framings that create mental pictures
      - **What it's NOT:** Sometimes clarifying misconceptions or ruling out wrong interpretations is the fastest path to understanding
      - **Why it matters:** Connect to things the reader already cares about. Make the stakes clear.

      The mark of true understanding is explaining something complex simply. Your audience is intelligent but not specialized — they can follow sophisticated reasoning if it's presented clearly.

      Aim for the clarity of the best science journalism or the most accessible TED talks, while preserving intellectual honesty.
      """,
      anti_repetition_footer()
    ])
  end

  @doc """
  Simplify a specific text selection for accessibility.
  """
  @spec simplify_selection(String.t(), String.t()) :: String.t()
  def simplify_selection(context, selection_text) do
    join_blocks([
      frame_minimal_context(context),
      """
      A specific statement or concept was highlighted from the text above: **#{sanitize_title(selection_text)}**

      **Your task:** Make this selection accessible to a general audience.

      Simplify without dumbing down:
      - **Core insight first:** Lead with the central point in plain language. What's the one thing someone should take away?
      - **Jargon translation:** Replace technical terms with everyday language, or explain them with vivid analogies
      - **Concrete examples:** Ground abstractions in tangible, relatable scenarios from everyday life
      - **Progressive complexity:** Start simple, then add nuance. Let readers go as deep as they want.
      - **Visual thinking:** Use spatial metaphors, comparisons to familiar objects, or "imagine..." framings
      - **What it's NOT:** Clarify misconceptions or rule out wrong interpretations
      - **Why it matters:** Connect to things the reader already cares about. Make the stakes clear.

      Your audience is intelligent but not specialized — they can follow sophisticated reasoning if it's presented clearly.

      Aim for the clarity of the best science journalism while preserving intellectual honesty.
      """
    ])
  end
end
