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
  - Headings are flexible; narrative flow beats rigid sections.
  - No tables. Sparse italics for emphasis; em dashes allowed.

  Information Hygiene
  - Open with an evocative hook (1–2 lines), then one crisp plain-language definition.
  - Prefer Context. Extra info is **Background**;

  Signature Moves (pick 1–2, not all)
  - Analogy pivot (vivid but accurate).
  - Micro-story (2–4 lines) that illustrates the mechanism.
  - Tension spotlight (a sharp contrast or trade-off).
  - Bridge-home takeaway (actionable next experiment).

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
        Task: Make a creative yet rigorous case for the **Claim**.
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
        Task: Critique the **Target Claim** fairly—steelman first, then challenge.
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

        """
      ],
      "\n\n"
    )
  end
end
