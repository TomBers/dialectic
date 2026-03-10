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

  # ===========================================================================
  # Cluster 1 — Core Inquiry Moves
  # ===========================================================================

  @doc """
  Conceptual clarification: "What do you mean by…?"
  Identify how key terms are being used and prevent misunderstandings.
  """
  @spec clarify(String.t(), String.t()) :: String.t()
  def clarify(context, claim) do
    join_blocks([
      frame_context(context),
      """
      **Your task:** Perform a conceptual clarification of: **#{sanitize_title(claim)}**

      Carefully examine the key terms and concepts used in this claim. For each important term or phrase:

      1. **Identify ambiguity** — Is the term being used in a specific technical sense, a colloquial sense, or does it shift meaning within the argument?
      2. **Distinguish meanings** — If a term has multiple possible meanings, spell them out. Show how the claim changes depending on which meaning is intended.
      3. **Surface hidden definitions** — Are there concepts that seem clear on the surface but actually smuggle in contestable assumptions about what counts as X or what qualifies as Y?
      4. **Test the boundaries** — What are edge cases where the definition breaks down? What would the speaker need to exclude or include for the term to do the work they need it to do?

      Structure your response around the 2-4 most pivotal terms. For each, show how clarifying the term reshapes our understanding of the overall claim.
      """,
      citation_encouragement(),
      anti_repetition_footer()
    ])
  end

  @doc """
  Conceptual clarification for a text selection.
  """
  @spec clarify_selection(String.t(), String.t()) :: String.t()
  def clarify_selection(context, selection_text) do
    join_blocks([
      frame_minimal_context(context),
      """
      A specific passage was highlighted: **#{sanitize_title(selection_text)}**

      **Your task:** Perform a conceptual clarification of this passage.

      Carefully examine the key terms and concepts used. For each important term or phrase:

      1. **Identify ambiguity** — Is the term being used in a specific technical sense, a colloquial sense, or does it shift meaning?
      2. **Distinguish meanings** — If a term has multiple possible meanings, spell them out. Show how the passage changes depending on which meaning is intended.
      3. **Surface hidden definitions** — Are there concepts that seem clear on the surface but actually smuggle in contestable assumptions?
      4. **Test the boundaries** — What are edge cases where the definition breaks down?

      Focus on the 2-4 most pivotal terms that shape the meaning of this passage.
      """,
      citation_encouragement()
    ])
  end

  @doc """
  Assumption identification: "What has to be true?"
  Surface the hidden premises required for a claim to hold.
  """
  @spec assumptions(String.t(), String.t()) :: String.t()
  def assumptions(context, claim) do
    join_blocks([
      frame_context(context),
      """
      **Your task:** Identify the hidden assumptions underlying: **#{sanitize_title(claim)}**

      For this claim to hold, certain things must be true — but they are rarely stated explicitly. Dig beneath the surface and categorize the assumptions:

      1. **Factual assumptions** — What empirical claims about how the world works are being taken for granted? What would have to be true about cause-and-effect, human behavior, or how systems operate?
      2. **Value assumptions** — What judgments about what matters, what is good, or what should be prioritized are embedded in this claim? Whose values are centered, and whose are marginalized?
      3. **Conceptual assumptions** — How are key concepts being defined or framed? What conceptual boundaries are assumed that could be drawn differently?
      4. **Logical assumptions** — What inferential leaps are being made? Where does the argument assume that A leads to B without justifying the connection?

      For each assumption, explain:
      - Why it matters — how the claim depends on it
      - Whether it is contestable — and who might contest it
      - What happens to the claim if this assumption is false

      Conclude with a brief assessment: which assumptions are the most vulnerable, and where do the real disagreements likely lie?
      """,
      citation_encouragement(),
      anti_repetition_footer()
    ])
  end

  @doc """
  Assumption identification for a text selection.
  """
  @spec assumptions_selection(String.t(), String.t()) :: String.t()
  def assumptions_selection(context, selection_text) do
    join_blocks([
      frame_minimal_context(context),
      """
      A specific passage was highlighted: **#{sanitize_title(selection_text)}**

      **Your task:** Identify the hidden assumptions underlying this passage.

      Categorize the assumptions:

      1. **Factual assumptions** — What empirical claims about how the world works are taken for granted?
      2. **Value assumptions** — What judgments about what matters or should be prioritized are embedded?
      3. **Conceptual assumptions** — How are key concepts being defined or framed?
      4. **Logical assumptions** — What inferential leaps are being made?

      For each assumption, explain why it matters, whether it is contestable, and what happens if it is false.
      """,
      citation_encouragement()
    ])
  end

  @doc """
  Counterexample testing: "Is that always true?"
  Identify exceptions, boundary cases, or situations where the claim may fail.
  """
  @spec counterexample(String.t(), String.t()) :: String.t()
  def counterexample(context, claim) do
    join_blocks([
      frame_context(context),
      """
      **Your task:** Test the strength and scope of this claim by finding counterexamples: **#{sanitize_title(claim)}**

      Systematically probe the boundaries of this claim:

      1. **Direct counterexamples** — Can you find real-world cases, historical examples, or documented instances where this claim clearly fails? Be specific with names, dates, and details.
      2. **Edge cases** — What happens at the extremes? When you push the claim to its logical limits, where does it break down?
      3. **Domain boundaries** — Does this hold in all contexts? Test it across different cultures, time periods, scales, or fields. Where does the domain of validity end?
      4. **Conditional exceptions** — Under what specific conditions does the claim fail? What would have to change for it to no longer hold?

      For each counterexample:
      - Describe the case vividly and specifically
      - Explain exactly why it challenges the claim
      - Assess severity — is this a fatal blow to the claim, or merely a boundary condition that requires qualification?

      Conclude by assessing: Is this a universal claim that has been disproven, a general tendency with known exceptions, or something in between? How should the claim be reformulated to account for what you've found?
      """,
      citation_encouragement(),
      anti_repetition_footer()
    ])
  end

  @doc """
  Counterexample testing for a text selection.
  """
  @spec counterexample_selection(String.t(), String.t()) :: String.t()
  def counterexample_selection(context, selection_text) do
    join_blocks([
      frame_minimal_context(context),
      """
      A specific passage was highlighted: **#{sanitize_title(selection_text)}**

      **Your task:** Test the strength and scope of this claim by finding counterexamples.

      1. **Direct counterexamples** — Real-world cases where this claim clearly fails
      2. **Edge cases** — What happens at the extremes?
      3. **Domain boundaries** — Does this hold across all contexts, cultures, time periods?
      4. **Conditional exceptions** — Under what conditions does the claim fail?

      For each counterexample, describe it vividly, explain why it challenges the claim, and assess whether it is fatal or merely requires qualification.
      """,
      citation_encouragement()
    ])
  end

  @doc """
  Implication tracing: "So what?"
  Explore the consequences of accepting the claim.
  """
  @spec implications(String.t(), String.t()) :: String.t()
  def implications(context, claim) do
    join_blocks([
      frame_context(context),
      """
      **Your task:** Trace the implications of accepting this claim: **#{sanitize_title(claim)}**

      If we take this claim seriously and follow it where it leads, what follows? Explore the consequences systematically:

      1. **Immediate logical consequences** — What must also be true if this claim is true? What conclusions follow directly from it?
      2. **Practical implications** — How would accepting this claim change what we do? What policies, practices, or behaviors would need to change?
      3. **Conceptual commitments** — What other beliefs or frameworks are we committed to if we accept this? What worldview does this claim belong to?
      4. **Uncomfortable consequences** — Does following this claim to its logical conclusion lead anywhere surprising, troubling, or counter to the arguer's likely intentions?
      5. **Cascading effects** — What second- and third-order consequences emerge? How might accepting this reshape adjacent debates?

      For each implication, clearly show the logical chain from the original claim to the consequence. Flag any implications that would be controversial or that the original arguer might not have intended.
      """,
      citation_encouragement(),
      anti_repetition_footer()
    ])
  end

  @doc """
  Implication tracing for a text selection.
  """
  @spec implications_selection(String.t(), String.t()) :: String.t()
  def implications_selection(context, selection_text) do
    join_blocks([
      frame_minimal_context(context),
      """
      A specific passage was highlighted: **#{sanitize_title(selection_text)}**

      **Your task:** Trace the implications of accepting this claim. If we take it seriously, what follows?

      1. **Immediate logical consequences** — What must also be true?
      2. **Practical implications** — What changes in practice?
      3. **Conceptual commitments** — What worldview does this belong to?
      4. **Uncomfortable consequences** — Where does following this to its logical conclusion lead?
      5. **Cascading effects** — What second- and third-order consequences emerge?

      Show the logical chain from the original claim to each consequence.
      """,
      citation_encouragement()
    ])
  end

  @doc """
  Blind-spot detection: "What's missing?"
  Identify overlooked perspectives, missing information, or unexamined aspects.
  """
  @spec blind_spots(String.t(), String.t()) :: String.t()
  def blind_spots(context, claim) do
    join_blocks([
      frame_context(context),
      """
      **Your task:** Identify what's missing from this argument: **#{sanitize_title(claim)}**

      Every argument has blind spots — perspectives it doesn't consider, evidence it overlooks, questions it doesn't ask. Systematically map the gaps:

      1. **Missing perspectives** — Whose voice, experience, or viewpoint is absent? Who is affected but not consulted? What traditions, cultures, or disciplines would frame this differently?
      2. **Missing evidence** — What data, studies, or empirical observations are not being considered? What would a skeptic want to see before being convinced?
      3. **Unasked questions** — What obvious questions does this argument fail to raise? What are the elephants in the room?
      4. **Missing context** — What historical, cultural, economic, or institutional context would change how we evaluate this claim?
      5. **Excluded alternatives** — What other possible explanations, solutions, or framings have been implicitly ruled out? Why might they have been excluded?

      For each blind spot:
      - Explain what is missing and why it matters
      - Suggest how including it might change the argument
      - Assess whether the omission seems deliberate or accidental

      Conclude with the 2-3 most significant gaps that, if filled, would most transform the argument.
      """,
      citation_encouragement(),
      anti_repetition_footer()
    ])
  end

  @doc """
  Blind-spot detection for a text selection.
  """
  @spec blind_spots_selection(String.t(), String.t()) :: String.t()
  def blind_spots_selection(context, selection_text) do
    join_blocks([
      frame_minimal_context(context),
      """
      A specific passage was highlighted: **#{sanitize_title(selection_text)}**

      **Your task:** Identify what's missing from this argument.

      1. **Missing perspectives** — Whose voice or viewpoint is absent?
      2. **Missing evidence** — What data or observations are not being considered?
      3. **Unasked questions** — What obvious questions does this fail to raise?
      4. **Missing context** — What historical or cultural context would change the evaluation?
      5. **Excluded alternatives** — What other explanations or framings have been ruled out?

      For each blind spot, explain what is missing, why it matters, and how including it might change the argument.
      """,
      citation_encouragement()
    ])
  end

  # ===========================================================================
  # Cluster 2 — Context and Dialectical Expansion
  # ===========================================================================

  @doc """
  Source/authority check: "Says who?"
  Examine where the claim comes from and what evidence or authority supports it.
  """
  @spec says_who(String.t(), String.t()) :: String.t()
  def says_who(context, claim) do
    join_blocks([
      frame_context(context),
      """
      **Your task:** Examine the sources, evidence, and authority behind this claim: **#{sanitize_title(claim)}**

      Investigate the epistemic foundations:

      1. **Origin and lineage** — Where does this idea come from? Who first articulated it, and in what context? How has it been transmitted and transformed over time?
      2. **Evidence base** — What kind of evidence supports this claim? Is it empirical research, philosophical argument, tradition, expert consensus, anecdote, or intuition? How strong is each type of support?
      3. **Authority and credibility** — Who are the key proponents? What qualifies them? Are there conflicts of interest, ideological commitments, or institutional pressures that might shape the claim?
      4. **Methodological scrutiny** — If based on research, what methods were used? Have the findings been replicated? What are the known limitations?
      5. **Counter-authorities** — Who are equally credible voices that disagree? What alternative evidence exists?

      Be specific: name actual thinkers, cite actual studies or works, and assess the quality of the evidence trail. The goal is to help the reader evaluate not just *what* is claimed but *why anyone should believe it*.
      """,
      citation_encouragement_for_deep_dive(),
      anti_repetition_footer()
    ])
  end

  @doc """
  Source/authority check for a text selection.
  """
  @spec says_who_selection(String.t(), String.t()) :: String.t()
  def says_who_selection(context, selection_text) do
    join_blocks([
      frame_minimal_context(context),
      """
      A specific passage was highlighted: **#{sanitize_title(selection_text)}**

      **Your task:** Examine the sources, evidence, and authority behind this claim.

      1. **Origin and lineage** — Where does this idea come from? Who first articulated it?
      2. **Evidence base** — What kind of evidence supports this? How strong is it?
      3. **Authority and credibility** — Who are the key proponents? What qualifies them?
      4. **Counter-authorities** — Who are equally credible voices that disagree?

      Be specific: name actual thinkers, cite actual works, and assess the quality of the evidence trail.
      """,
      citation_encouragement_for_deep_dive()
    ])
  end

  @doc """
  Perspective challenge: "Who would disagree?"
  Identify thinkers, traditions, or viewpoints that might challenge the claim.
  """
  @spec who_disagrees(String.t(), String.t()) :: String.t()
  def who_disagrees(context, claim) do
    join_blocks([
      frame_context(context),
      """
      **Your task:** Identify who would disagree with this claim and why: **#{sanitize_title(claim)}**

      Map the landscape of opposition:

      1. **Named critics** — Identify specific thinkers, scholars, or public figures who have argued against this position or similar ones. What are their core objections? Cite their actual arguments.
      2. **Intellectual traditions** — What schools of thought, philosophical traditions, or disciplinary perspectives fundamentally challenge this framing? (e.g., a Marxist critique of a liberal claim, a pragmatist response to a rationalist argument)
      3. **Stakeholder opposition** — Who is materially affected by this claim in ways that would lead them to resist it? What are their lived-experience objections?
      4. **Internal critics** — Even among those sympathetic to the broad position, who would push back on this specific formulation? What friendly amendments would they propose?
      5. **The strongest objection** — Of all the disagreements identified, which is the most intellectually formidable? Why?

      For each source of disagreement, present the objection in its strongest form — as the critic themselves would want it stated. Show the reader that the opposition has genuine intellectual weight.
      """,
      citation_encouragement_for_arguments(),
      anti_repetition_footer()
    ])
  end

  @doc """
  Perspective challenge for a text selection.
  """
  @spec who_disagrees_selection(String.t(), String.t()) :: String.t()
  def who_disagrees_selection(context, selection_text) do
    join_blocks([
      frame_minimal_context(context),
      """
      A specific passage was highlighted: **#{sanitize_title(selection_text)}**

      **Your task:** Identify who would disagree with this claim and why.

      1. **Named critics** — Specific thinkers who have argued against this or similar positions
      2. **Intellectual traditions** — Schools of thought that fundamentally challenge this framing
      3. **Stakeholder opposition** — Who is affected in ways that would lead them to resist?
      4. **The strongest objection** — Which disagreement is the most intellectually formidable?

      Present each objection in its strongest form — as the critic themselves would want it stated.
      """,
      citation_encouragement_for_arguments()
    ])
  end

  @doc """
  Analogy: "What is this like?"
  Use comparisons with similar cases or concepts to illuminate the structure of the idea.
  """
  @spec analogy(String.t(), String.t()) :: String.t()
  def analogy(context, claim) do
    join_blocks([
      frame_context(context),
      """
      **Your task:** Illuminate this idea through analogies and comparisons: **#{sanitize_title(claim)}**

      Analogical reasoning is one of the most powerful tools for understanding unfamiliar or abstract ideas. Find illuminating parallels:

      1. **Structural analogies** — What other situations, systems, or phenomena share the same underlying structure or logic? Map the correspondence precisely: what plays the role of what?
      2. **Historical parallels** — Has something like this happened before in a different context? What can we learn from the parallel case?
      3. **Cross-domain analogies** — How does this idea map onto concepts from other fields? (e.g., a political concept through the lens of ecology, an economic idea through the lens of physics)
      4. **Everyday analogies** — Can this be compared to something from ordinary life that makes the abstract concrete and intuitive?
      5. **Where the analogy breaks** — Every analogy has limits. For each comparison, identify where it stops working and what the breakdown reveals about the original idea.

      For each analogy:
      - State the comparison clearly
      - Map the structural correspondence (A is to B as C is to D)
      - Explain what the analogy illuminates that was hard to see before
      - Identify where the analogy breaks down and what that teaches us

      Aim for 3-4 analogies that each reveal a different aspect of the idea.
      """,
      citation_encouragement(),
      anti_repetition_footer()
    ])
  end

  @doc """
  Analogy for a text selection.
  """
  @spec analogy_selection(String.t(), String.t()) :: String.t()
  def analogy_selection(context, selection_text) do
    join_blocks([
      frame_minimal_context(context),
      """
      A specific passage was highlighted: **#{sanitize_title(selection_text)}**

      **Your task:** Illuminate this idea through analogies and comparisons.

      1. **Structural analogies** — What shares the same underlying logic? Map the correspondence precisely.
      2. **Historical parallels** — Has something like this happened before?
      3. **Cross-domain analogies** — How does this map onto concepts from other fields?
      4. **Everyday analogies** — Can this be compared to something from ordinary life?
      5. **Where the analogy breaks** — What do the limits of each analogy reveal?

      For each analogy, state the comparison, map the structural correspondence, explain what it illuminates, and identify where it breaks down.
      """,
      citation_encouragement()
    ])
  end

  @doc """
  Steel man: charitable reconstruction of the opposing view.
  Generate the strongest version of the opposing argument.
  """
  @spec steel_man(String.t(), String.t()) :: String.t()
  def steel_man(context, claim) do
    join_blocks([
      frame_context(context),
      """
      **Your task:** Steel man the opposing view of this claim: **#{sanitize_title(claim)}**

      A steel man is the opposite of a straw man — instead of weakening the opposing argument, you make it as strong as possible. This is intellectual generosity in service of better thinking.

      1. **Identify the opposition** — What is the strongest version of the view that opposes or challenges this claim? Who holds it, and what motivates them?
      2. **Reconstruct charitably** — Present the opposing argument in its most compelling, sophisticated form. Use the best evidence, the most careful reasoning, and the most sympathetic framing. Write it as a thoughtful proponent would.
      3. **Strengthen the weaknesses** — Where does the opposing view typically stumble? Fix those problems. Provide the evidence, arguments, or qualifications that the best version of this position would include.
      4. **Show the genuine insight** — What does the opposing view see that the original claim misses? What kernel of truth makes this position worth taking seriously?
      5. **The challenge it poses** — Having built the strongest possible version of the opposition, what is the most difficult question it raises for the original claim?

      Write the steel man as if you genuinely hold the opposing view and are trying to convince a skeptical but fair-minded audience.
      """,
      citation_encouragement_for_arguments(),
      anti_repetition_footer()
    ])
  end

  @doc """
  Steel man for a text selection.
  """
  @spec steel_man_selection(String.t(), String.t()) :: String.t()
  def steel_man_selection(context, selection_text) do
    join_blocks([
      frame_minimal_context(context),
      """
      A specific passage was highlighted: **#{sanitize_title(selection_text)}**

      **Your task:** Steel man the opposing view of this claim.

      1. **Identify the opposition** — What is the strongest version of the view that opposes this?
      2. **Reconstruct charitably** — Present the opposing argument in its most compelling form
      3. **Strengthen the weaknesses** — Fix the typical problems in the opposing view
      4. **Show the genuine insight** — What does the opposition see that this claim misses?
      5. **The challenge it poses** — What is the most difficult question the opposition raises?

      Write as if you genuinely hold the opposing view and are trying to convince a fair-minded audience.
      """,
      citation_encouragement_for_arguments()
    ])
  end

  @doc """
  Scenario testing / thought experiments: "What if…?"
  Test the claim under hypothetical or alternative conditions.
  """
  @spec what_if(String.t(), String.t()) :: String.t()
  def what_if(context, claim) do
    join_blocks([
      frame_context(context),
      """
      **Your task:** Test this claim through thought experiments and hypothetical scenarios: **#{sanitize_title(claim)}**

      Thought experiments are a time-honored tool for stress-testing ideas. Design scenarios that reveal the claim's strengths, limits, and hidden features:

      1. **Extreme cases** — What happens if we push the key variables to their extremes? Imagine scenarios where the central factors are maximized or minimized.
      2. **Inversion** — What if the opposite were true? What would the world look like? What can we learn from imagining the negation?
      3. **Different context** — Transplant this claim to a radically different setting (another era, culture, scale, or domain). Does it still hold? What changes?
      4. **Missing piece** — What if a key element assumed by the claim didn't exist? Remove a crucial assumption and trace what happens.
      5. **Classic thought experiments** — If any well-known philosophical thought experiments (trolley problems, Rawls' veil of ignorance, brain in a vat, ship of Theseus, etc.) are relevant, apply them to this claim.

      For each scenario:
      - Set the scene vividly — make it concrete and imaginable
      - Trace the consequences through carefully
      - Explain what the thought experiment reveals about the original claim
      - Note whether it supports, undermines, or complicates the claim
      """,
      citation_encouragement(),
      anti_repetition_footer()
    ])
  end

  @doc """
  Scenario testing for a text selection.
  """
  @spec what_if_selection(String.t(), String.t()) :: String.t()
  def what_if_selection(context, selection_text) do
    join_blocks([
      frame_minimal_context(context),
      """
      A specific passage was highlighted: **#{sanitize_title(selection_text)}**

      **Your task:** Test this claim through thought experiments and hypothetical scenarios.

      1. **Extreme cases** — What if the key variables are pushed to their extremes?
      2. **Inversion** — What if the opposite were true?
      3. **Different context** — Transplant to a radically different setting. Does it still hold?
      4. **Missing piece** — Remove a crucial assumption. What happens?
      5. **Classic thought experiments** — Apply any relevant philosophical thought experiments.

      For each scenario, set the scene vividly, trace the consequences, and explain what it reveals about the claim.
      """,
      citation_encouragement()
    ])
  end

  # ===========================================================================
  # Cluster 3 — Clarity and Communication
  # ===========================================================================

  @doc """
  Clarity test: "Rewrite for a 10-year-old"
  Simplify the claim to reveal confusion or hidden complexity.
  """
  @spec simplify(String.t(), String.t()) :: String.t()
  def simplify(context, claim) do
    join_blocks([
      frame_context(context),
      """
      **Your task:** Rewrite this idea so a curious 10-year-old could understand it: **#{sanitize_title(claim)}**

      This is not just about dumbing things down — it's a clarity test. If you can't explain it simply, you might not understand it well enough. The goal is to reveal hidden complexity and confusion by forcing radical simplicity.

      1. **The simple version** — Rewrite the core idea using only everyday language, concrete examples, and vivid metaphors. No jargon, no abstractions without an anchor in experience. Imagine explaining this to a bright, curious child who asks great questions.

      2. **What got lost** — After the simple version, honestly flag what you had to leave out or simplify to the point of distortion. What nuances, qualifications, or subtleties resist simplification? These are often the most interesting parts.

      3. **What got clearer** — Sometimes simplification reveals that the original was hiding confusion behind complexity. Did the forced simplicity expose any circular reasoning, vague handwaving, or concepts that don't actually mean anything clear?

      4. **The "why should I care?" test** — A 10-year-old will always ask "but why does that matter?" Answer that question honestly and directly.

      Write the simplified version first, then the analysis. The simplified version should be genuinely engaging and understandable — not condescending.
      """,
      anti_repetition_footer()
    ])
  end

  @doc """
  Clarity test for a text selection.
  """
  @spec simplify_selection(String.t(), String.t()) :: String.t()
  def simplify_selection(context, selection_text) do
    join_blocks([
      frame_minimal_context(context),
      """
      A specific passage was highlighted: **#{sanitize_title(selection_text)}**

      **Your task:** Rewrite this so a curious 10-year-old could understand it.

      1. **The simple version** — Use only everyday language, concrete examples, and vivid metaphors. No jargon.
      2. **What got lost** — What nuances had to be left out? These are often the most interesting parts.
      3. **What got clearer** — Did forced simplicity expose any confusion hidden behind complexity?
      4. **The "why should I care?" test** — Answer this honestly and directly.

      Write the simplified version first, then the analysis.
      """
    ])
  end
end
