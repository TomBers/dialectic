defmodule Dialectic.Responses.PromptsCreative do
  @moduledoc """
  Creative prompt builders for LLM interactions.

  Mirrors the `Dialectic.Responses.PromptsStructured` surface but guides the model
  toward a freer, more narrative and exploratory style. Functions are pure and
  return the final prompt text (style preamble included), so they are easy to test
  and swap based on a user-selected mode.
  """

  # ---- Helpers ---------------------------------------------------------------

  # Fences arbitrary content so the model treats it as data, not instructions.
  defp fence(label, text) do
    """
    ### #{label}
    ```text
    #{text}
    ```
    """
  end

  @style """
  Persona: A thoughtful guide. Curious, vivid, and rigorous. Uses story and analogy to spark insight.

  Voice & Tone
  - Warm, lively, intellectually honest. You may use “you”.
  - Carefully chosen metaphor or micro-story allowed.
  - Label any guesswork as **Speculation**.

  Rhythm & Sentence Rules
  - Varied cadence: mix short punchy lines with longer arcs.
  - Hooks welcome; occasional rhetorical question to prime curiosity.
  - Short paragraphs (2–4 sentences). Bullets only for emphasis.

  Formatting
  - H2 titles encouraged and may be playful.
  - Always start the output with the H2 title shown in the template.
  - Title rules: follow the exact template string; never invent, rename, or omit titles.
  - Placeholder convention: replace any {Label} with the exact input text; do not include braces or quotes.
  - If an input label is empty or missing, state the gap and ask one direct question instead of inventing a title.
  - Keep to only the sections requested; do not add, rename, or remove headings.
  - Headings are flexible when allowed, but the template sections are mandatory.
  - No tables. Sparse italics for emphasis; em dashes allowed.


  Information Hygiene
  - Open with an evocative hook (1–2 lines), then one crisp plain-language definition.
  - Context in plain terms.
  - Prefer Context. Extra info is **Background**;

  Language Preferences
  - Concrete imagery when it clarifies. Verbs that move: nudge, probe, hedge, snap, drift.
  - Avoid hype or purple prose; delight comes from clarity.

  Red Lines
  - No long lists or academic throat-clearing.
  - Don’t hide definitions—state one early.

  Quality Checks
  - The hook makes the idea feel alive without distortion.
  - Includes at least one precise definition in plain language.
  - Ends with an actionable next step or question.
  """

  # ---- Templates -------------------------------------------------------------

  @doc """
  Builds a prompt that explains a single topic for a curious learner using a narrative style.

  Parameters:
    - context: Text block describing the current node’s context.
    - topic: A short label or the node content that the explanation should focus on.
  """
  @spec explain(String.t(), String.t()) :: String.t()
  def explain(context, topic) do
    Enum.join(
      [
        @style,
        fence("Context", context),
        fence("Topic", topic),
        """
        Task: Offer a narrative exploration of the **Topic**.

        Output:
        ## Explain: {Topic}
        - Hook (1–2 lines), then a plain-language definition (1 line).

        ### Story-driven explanation
        - 1 short paragraph: intuition and why it matters.
        - 1 short paragraph: mechanism or how it works in practice.

        ### Subtleties
        - 2–3 bullets: pitfalls, contrasts, or edge cases.

        Respond with Markdown only, begin with the H2 title, and include only the sections above.
        """
      ],
      "\n\n"
    )
  end

  @doc """
  Builds a prompt that applies a selection/instruction to the current context, with a freer tone.

  Parameters:
    - context: Text block describing the current node’s context.
    - selection_text: Instruction/selection text to apply to the context.
  """
  @spec selection(String.t(), String.t()) :: String.t()
  def selection(context, selection_text) do
    Enum.join(
      [
        @style,
        fence("Context", context),
        fence("Selection", selection_text),
        """
        If no **Selection** is provided, say so and ask for it (one sentence at end).

        Output:
        ## Apply: {Selection}
        - Paraphrase (1–2 sentences).

        ### Why it matters here
        - Claims/evidence (2–3 bullets).
        - Assumptions/definitions (1–2 bullets).
        - Implications (1–2 bullets).
        - Limitations/alternative readings (1–2 bullets).

        Respond with Markdown only, begin with the H2 title, and include only the sections above.
        """
      ],
      "\n\n"
    )
  end

  @doc """
  Builds a prompt to synthesize two positions using a narrative bridge and creative contrasts.

  Parameters:
    - context1: Context block for the first argument/position.
    - context2: Context block for the second argument/position.
    - pos1: Short label or content for the first position.
    - pos2: Short label or content for the second position.
  """
  @spec synthesis(String.t(), String.t(), String.t(), String.t()) :: String.t()
  def synthesis(context1, context2, pos1, pos2) do
    Enum.join(
      [
        @style,
        fence("Context A", context1),
        fence("Context B", context2),
        fence("Position A", pos1),
        fence("Position B", pos2),
        """
        Task: Weave a creative synthesis of **Position A** and **Position B** that respects both,
        clarifies where they shine, and proposes a bridge or a useful boundary.

        Output:
        ## Synthesis: {Position A} vs {Position B}
        - Short summary (1–2 sentences) of the relationship.

        ### Narrative bridge
        - 1–2 short paragraphs on common ground and key tensions; make explicit the assumptions driving disagreement.

        ### Bridge or boundary
        - 1 short paragraph proposing a synthesis or scope boundary; add a testable prediction if helpful.

        ### When each view is stronger
        - 2–3 concise bullets on contexts where each view wins and the remaining trade-offs.

        Respond with Markdown only, begin with the H2 title, and include only the sections above.
        """
      ],
      "\n\n"
    )
  end

  @doc """
  Builds a prompt to argue for a claim with a lively but grounded narrative voice.

  Parameters:
    - context: The current context block.
    - claim: The claim/topic to argue in favor of.
  """
  @spec thesis(String.t(), String.t()) :: String.t()
  def thesis(context, claim) do
    Enum.join(
      [
        @style,
        fence("Context", context),
        fence("Claim", claim),
        """
        Task: Make a creative yet rigorous argument for the **Claim**.

        Output:
        ## In favor of: {Claim}
        - Argument claim (1 sentence) — clearly state what is being argued for.
        - Reasons (2–3 short bullets): each names a reason and briefly explains why it supports the claim.
        - Evidence/examples (1–2 lines): concrete facts, cases, or citations tied to the reasons.
        - Counter-arguments & rebuttals (1–2 bullets): strongest opposing points and succinct rebuttals.
        - Assumptions & limits (1 line) + a falsifiable prediction.
        - Applicability (1 line): where this argument is strongest vs. where it likely fails.

        Respond with Markdown only, begin with the H2 title, and include only the sections above.
        """
      ],
      "\n\n"
    )
  end

  @doc """
  Builds a prompt to argue against a claim with fairness and imaginative clarity.

  Parameters:
    - context: The current context block.
    - claim: The claim/topic to argue against.
  """
  @spec antithesis(String.t(), String.t()) :: String.t()
  def antithesis(context, claim) do
    Enum.join(
      [
        @style,
        fence("Context", context),
        fence("Target Claim", claim),
        """
        Task: Critique the **Target Claim** with creative clarity—steelman first, then challenge.

        Output:
        ## Against: {Target Claim}
        - Central critique (1 sentence) — clearly state what is being argued against.
        - Reasons (2–3 short bullets): each names a reason and briefly explains why it undermines the claim.
        - Evidence/counterexamples (1–2 lines): concrete facts, cases, or citations tied to the reasons.
        - Steelman & rebuttal (1–2 bullets): acknowledge the best pro point(s) and explain why they’re insufficient.
        - Scope & limits (1 line) + a falsifiable prediction that would weaken this critique.
        - Applicability (1 line): when this critique applies vs. when it likely does not.

        Respond with Markdown only, begin with the H2 title, and include only the sections above.
        """
      ],
      "\n\n"
    )
  end

  @doc """
  Builds a prompt to generate a creative list of related and contrasting ideas.

  Parameters:
    - context: The current context block.
    - current_idea_title: Title/label of the current idea.
  """
  @spec related_ideas(String.t(), String.t()) :: String.t()
  def related_ideas(context, current_idea_title) do
    Enum.join(
      [
        @style,
        fence("Context", context),
        fence("Current Idea", current_idea_title),
        """
        Task: Generate a creative list of related but distinct concepts worth exploring next.

        Output:
        ## What to explore next: {Current Idea}
        - Provide 3–4 bullets. Each: Concept — 1 sentence (difference/relevance; optional method/author/example).

        ### Adjacent concepts
        - Provide 3–4 bullets. Each: Concept — 1 sentence (link/relevance; optional method/author/example).

        ### Practical applications
        - Provide 3–4 bullets. Each: Concept — 1 sentence (use-case/why it matters; optional method/author/example).

        Respond with Markdown only, begin with the H2 title, and include only the sections above.
        """
      ],
      "\n\n"
    )
  end

  @doc """
  Builds a prompt for a creative deep dive with a narrative arc.

  Parameters:
    - context: The current context block.
    - topic: Topic to deep dive into.
  """
  @spec deep_dive(String.t(), String.t()) :: String.t()
  def deep_dive(context, topic) do
    Enum.join(
      [
        @style,
        fence("Context", context),
        fence("Concept", topic),
        """
        Task: Compose a narrative deep dive into the **Concept** that blends intuition,
        one crisp definition, and a few surprising connections.

        Output:
        ## Deep dive: {Concept}
        - One-sentence statement of what it is and when it applies.

        ### Deep dive
        - Core explanation (1–2 short paragraphs): mechanism, key assumptions, applicability.
        - (Optional) Nuance: 1–2 bullets with caveats or edge cases.

        Respond with Markdown only, begin with the H2 title, and include only the sections above.
        """
      ],
      "\n\n"
    )
  end
end
