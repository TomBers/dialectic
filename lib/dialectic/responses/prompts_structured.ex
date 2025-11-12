defmodule Dialectic.Responses.PromptsStructured do
  @moduledoc """
  Pure prompt builders for LLM interactions (Structured mode).

  This module isolates prompt text generation from any side effects
  (no I/O, no network, no process messaging). It enables simple, direct
  unit tests against the exact strings that will be sent to a model.

  Typical usage in calling code:
    question = Dialectic.Responses.PromptsStructured.explain(context, topic)
    # ...send `question` to your queue / LLM client

  You can also unit test each function directly by asserting on the returned strings.
  """

  # ---- Helpers ---------------------------------------------------------------

  # Fences arbitrary content so the model treats it as data, not instructions.
  defp fence(label, text) do
    """
    *** #{label} ***
    ```text
    #{text}
    ```
    """
  end

  @style """
  Persona: A precise lecturer. Efficient, calm, unemotional. Prioritizes mechanism and definitions.

  Voice & Tone
  - Direct, neutral, confident. No fluff or hype.
  - Metaphors only if they remove ambiguity.
  - Prefer third-person/impersonal voice; avoid “I”.

  Rhythm & Sentence Rules
  - Most sentences 8–18 words; avoid run-ons.
  - One idea per sentence; one claim per bullet.
  - Bullets are terse noun phrases or single sentences.

  Formatting
  - Always start the output with the H2 title shown in the template.
  - Headings only when they clarify; ≤ 3 levels.
  - No tables, emojis, or rhetorical questions.
  - Respond with Markdown only. Important ALWAYS begin with a title, and include only the sections requested.
  - Title rules: follow the exact template string; never invent, rename, or omit titles.
  - Placeholder convention for titles: replace any {Label} with the exact input text; do not include braces or quotes.
  - If an input label is empty or missing, state the gap and ask one direct question instead of inventing a title.

  Information Hygiene
  - Start with intuition (1–2 lines), then definitions/assumptions.
  - Prefer Context. Extra info is **Background**; low confidence: **Background — tentative**.
  - If blocked, state the gap and ask one direct question at the end.

  Language Preferences
  - Concrete verbs: estimate, update, converge, sample, backpropagate.
  - Avoid hedges: “somewhat”, “kind of”, “basically”, “arguably”.
  - Prefer canonical terms over synonyms.

  Red Lines
  - No exclamation marks, anecdotes, jokes, or scene-setting.
  - No “In this section we will…”. Just do it.

  Quality Checks
  - Every answer comes with a H2 title that explains the intent of the question.
  - Every paragraph advances the answer.
  - Give each symbol a brief gloss on first use.
  - Include at least one limit or failure mode if relevant.
  - Do not add sections beyond those requested.
  - Do not rename sections or headings.
  """

  # ---- Templates -------------------------------------------------------------

  @doc """
  Builds a prompt that explains a single topic for a first-time learner.

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
        Task: Teach a first-time learner about #{topic}

        Output:
        - Short answer (2–3 sentences): core idea + why it matters.

        ### Deep dive
        - Foundations (optional): key terms + assumptions (1 short paragraph).
        - Core explanation: mechanism + intuition (1–2 short paragraphs).
        - Nuances: 2–3 bullets (pitfalls/edge cases + one contrast).
        """
      ],
      "\n\n"
    )
  end

  @doc """
  Builds a prompt that applies a selection/instruction to the current context.

  Parameters:
    - context: Text block describing the current node’s context.
    - selection_text: The instruction/selection text to apply to the context.
  """
  @spec selection(String.t(), String.t()) :: String.t()
  def selection(context, selection_text) do
    Enum.join(
      [
        @style,
        fence("Context", context),
        fence("Selection", selection_text),
        """
        Output:
        ## Apply: {Selection}
        - Paraphrase (1–2 sentences).

        ### Why it matters here
        - Claims/evidence (2–3 bullets).
        - Assumptions/definitions (1–2 bullets).
        - Implications (1–2 bullets).
        - Limitations/alternative readings (1–2 bullets).
        """
      ],
      "\n\n"
    )
  end

  @doc """
  Builds a prompt to synthesize two positions for a first-time learner.

  Parameters:
    - context1: Context block for the first argument/position.
    - context2: Context block for the second argument/position.
    - pos1: A short label or first node’s content to reference in the synthesis instructions.
    - pos2: A short label or second node’s content to reference in the synthesis instructions.
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
        Task: Synthesize **Position A** and **Position B** for a first-time learner.

        Output:
        - Short summary (1–2 sentences) of the relationship.

        ### Deep dive
        - Narrative analysis: 1–3 short paragraphs (common ground + key tensions); make explicit the assumptions driving disagreement.
        """
      ],
      "\n\n"
    )
  end

  @doc """
  Builds a prompt to write a short, beginner-friendly but rigorous argument in support of a claim.

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
        Output:
        - Argument claim (1 sentence) — clearly state what is being argued for.
        - Reasons (2–3 short bullets): each names a reason and briefly explains why it supports the claim.
        - Evidence/examples (1–2 lines): concrete facts, cases, or citations tied to the reasons.
        - Counter-arguments & rebuttals (1–2 bullets): strongest opposing points and succinct rebuttals.
        - Assumptions & limits (1 line) + a falsifiable prediction.
        - Applicability (1 line): where this argument is strongest vs. where it likely fails.
        """
      ],
      "\n\n"
    )
  end

  @doc """
  Builds a prompt to write a short, beginner-friendly but rigorous argument against a claim.
  The instructions ask to steelman the opposing view.

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
        Output:
        - Central critique (1 sentence) — clearly state what is being argued against.
        - Reasons (2–3 short bullets): each names a reason and briefly explains why it undermines the claim.
        - Evidence/counterexamples (1–2 lines): concrete facts, cases, or citations tied to the reasons.
        - Steelman & rebuttal (1–2 bullets): acknowledge the best pro point(s) and explain why they’re insufficient.
        - Scope & limits (1 line) + a falsifiable prediction that would weaken this critique.
        - Applicability (1 line): when this critique applies vs. when it likely does not.
        """
      ],
      "\n\n"
    )
  end

  @doc """
  Builds a prompt to generate a beginner-friendly list of related but distinct concepts to explore.

  Parameters:
    - context: The current context block.
    - current_idea_title: Title/label of the current idea (concise phrase).
  """
  @spec related_ideas(String.t(), String.t()) :: String.t()
  def related_ideas(context, current_idea_title) do
    Enum.join(
      [
        @style,
        fence("Context", context),
        fence("Current Idea", current_idea_title),
        """
        Task: Generate related but distinct concepts for a first-time learner.

        Output:
        ### Adjacent concepts
        - Provide 3–4 concepts. Each: Concept — 1 paragraph (link/relevance; optional method/author/example).
        """
      ],
      "\n\n"
    )
  end

  @doc """
  Builds a prompt for a rigorous deep dive aimed at advanced learners.

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
        Task: Produce a rigorous deep dive into the **Concept** for an advanced learner.

        Output:
        - One-sentence statement of what it is and when it applies.

        ### Deep dive
        - Core explanation (1–3 short paragraphs): mechanism, key assumptions, applicability.
        - (Optional) Nuance: 1–2 bullets with caveats or edge cases.
        """
      ],
      "\n\n"
    )
  end
end
