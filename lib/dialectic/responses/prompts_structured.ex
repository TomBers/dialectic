defmodule Dialectic.Responses.PromptsStructured do
  @moduledoc """
  Pure prompt builders for LLM interactions.

  This module isolates all prompt text generation from any side effects
  (no I/O, no network, no process messaging). It enables simple, direct
  unit tests against the exact strings that will be sent to a model.

  Typical usage in calling code:
    question = Prompts.explain(context, topic)
    # ...send `question` to your queue / LLM client

  You can also unit test each function directly by asserting on the returned strings.
  """

  @style """
  Persona: A precise lecturer. Efficient, calm, and unemotional. Prioritizes mechanism and definitions.
  Voice & Tone
  - Direct, neutral, confident. No fluff, no hype.
  - Avoid metaphors unless they remove ambiguity.
  - Prefer third person or impersonal voice; avoid “I”.

  Rhythm & Sentence Rules
  - Average 12–16 words per sentence. No run-ons.
  - One idea per sentence; one claim per bullet.
  - Bullets are terse noun phrases or single sentences.

  Formatting
  - Always use an H2 title for standalone answers.
  - Headings only when they clarify; no more than 3 levels deep.
  - No tables. No emojis. No rhetorical questions.

  Information Hygiene
  - Start with intuition in 1–2 sentences, then definitions/assumptions.
  - Prefer Context. Mark extras as “Background” (and “Background — tentative” if low confidence).
  - If blocked by missing info, state the gap and ask one direct question at the end.

  Argument Shape (default)
  - Claim → Mechanism → Evidence/Example → Limits/Assumptions → Next step.
  - Procedures: 3–7 numbered steps; each step starts with a verb.

  Language Preferences
  - Use concrete verbs: estimate, update, converge, sample, backpropagate.
  - Avoid hedges: “somewhat”, “kind of”, “basically”, “arguably”.
  - Prefer canonical terms over synonyms.

  Red Lines
  - No exclamation marks, anecdotes, jokes, or scene-setting.
  - No “In this section we will…”. Just do it.

  Quality Checks
  - Every paragraph advances the answer.
  - Definitions are necessary and sufficient (no symbol without brief gloss).
  - One explicit limit or failure mode if relevant.
  """

  @doc """
  Builds a prompt that explains a single topic for a first-time learner.

  Parameters:
  - context: Text block describing the current node’s context.
  - topic: A short label or the node content that the explanation should focus on.
  """
  @spec explain(String.t(), String.t()) :: String.t()
  def explain(context, topic) do
    @style <>
      "\n\n" <>
      """
      Inputs: #{context}, #{topic}
      Task: Teach a first-time learner #{topic}.
      Output (~220–320 words, Markdown):
      ## [Short, descriptive title]
      - Short answer (2–3 sentences): core idea + why it matters.

      ### Deep dive
      - Foundations (optional): key terms + assumptions (1 short paragraph).
      - Core explanation: mechanism + intuition (1–2 short paragraphs).
      - Nuances: 2–3 bullets (pitfalls/edge cases + one contrast).

      ### Next steps
      - 1–2 next questions.
      """
  end

  @doc """
  Builds a prompt that applies a selection/instruction to the current context.

  If the selection text does not specify an output schema (headings or “Output (...)”),
  a default schema is appended automatically.

  Parameters:
  - context: Text block describing the current node’s context.
  - selection: The instruction/selection text to apply to the context.
  """
  @spec selection(String.t(), String.t()) :: String.t()
  def selection(context, selection) do
    add_default? = needs_default_selection_schema?(selection)

    base = """
    Inputs: #{context}, #{selection}
    If no selection is provided: state that and ask for it (one sentence at end).
    Output (180–260 words):
    ## [Short, descriptive title]
    - Paraphrase (1–2 sentences).

    ### Why it matters here
    - Claims/evidence (2–3 bullets).
    - Assumptions/definitions (1–2 bullets).
    - Implications (1–2 bullets).
    - Limitations/alternative readings (1–2 bullets).

    ### Next steps
    - 1–2 follow-up questions.
    """

    @style <>
      "\n\n" <>
      if add_default? do
        base <> "\n\n" <> default_selection_schema()
      else
        base
      end
  end

  @doc """
  Builds a prompt to synthesize two positions for a first-time learner.

  Parameters:
  - context1: Context block for the first argument/position.
  - context2: Context block for the second argument/position.
  - pos1: A short label or the first node’s content to reference in the synthesis instructions.
  - pos2: A short label or the second node’s content to reference in the synthesis instructions.
  """
  @spec synthesis(String.t(), String.t(), String.t(), String.t()) :: String.t()
  def synthesis(context1, context2, pos1, pos2) do
    @style <>
      "\n\n" <>
      """
      Context of first argument:
      #{context1}

      Context of second argument:
      #{context2}

      Task: Synthesize the positions in "#{pos1}" and "#{pos2}" for a first-time learner aiming for university-level understanding.

      Output (markdown):
      ## [Short, descriptive title]
      - Short summary (1–2 sentences) of the relationship between the two positions.

      ### Deep dive
      - Narrative analysis: 1–2 short paragraphs integrating common ground and the key tensions; make explicit the assumptions driving disagreement.
      - Bridge or delineation: 1 short paragraph proposing a synthesis or clarifying scope; add a testable prediction if helpful.
      - When each view is stronger and remaining trade‑offs: 2–3 concise bullets.

      ### Next steps
      - One concrete next step to test or explore.

      Constraints: ~220–320 words. If reconciliation is not possible, state the trade‑offs clearly.
      """
  end

  @doc """
  Builds a prompt to write a short, beginner‑friendly but rigorous argument in support of a claim.

  Parameters:
  - context: The current context block.
  - claim: The claim/topic to argue in favor of.
  """
  @spec thesis(String.t(), String.t()) :: String.t()
  def thesis(context, claim) do
    @style <>
      "\n\n" <>
      """
      Inputs: #{context}, #{claim}
      Output (150–200 words):
      ## [Title of the pro argument]
      - Claim (1 sentence).
      - Narrative reasoning (1–2 short paragraphs).
      - Example/evidence (1–2 lines).
      - Assumptions & limits (1 line) + falsifiable prediction.
      - When this holds vs. might not (1 line).
      """
  end

  @doc """
  Builds a prompt to write a short, beginner‑friendly but rigorous argument against a claim.
  The instructions ask to steelman the opposing view.

  Parameters:
  - context: The current context block.
  - claim: The claim/topic to argue against.
  """
  @spec antithesis(String.t(), String.t()) :: String.t()
  def antithesis(context, claim) do
    @style <>
      "\n\n" <>
      """
      Inputs: #{context}, #{claim}
      Output (150–200 words):
      ## [Title of the con argument]
      - Central critique (1 sentence).
      - Narrative reasoning (1–2 short paragraphs).
      - Counterexample/evidence (1–2 lines).
      - Scope & limits (1 line) + falsifiable prediction that would weaken the critique.
      - When this applies vs. not (1 line).
      """
  end

  @doc """
  Builds a prompt to generate a beginner‑friendly list of related but distinct concepts to explore.

  Parameters:
  - context: The current context block.
  - current_idea_title: Title/label of the current idea (ideally a concise H1/H2-like phrase).
  """
  @spec related_ideas(String.t(), String.t()) :: String.t()
  def related_ideas(context, current_idea_title) do
    @style <>
      "\n\n" <>
      """
      Inputs: #{context}, #{current_idea_title}
      Output (Markdown only; return only headings and bullets):
      ### Different/contrasting approaches
      - Concept — 1 sentence (difference/relevance; optional method/author/example).
      - …
      ### Adjacent concepts
      - …
      ### Practical applications
      - …
      """
  end

  @doc """
  Extracts a concise title from a content block by removing bold markers, an optional
  leading 'Title:' tag, markdown heading markers, and trimming whitespace. Uses only pure String/Regex ops.

  This mirrors the existing title-extraction behavior used for related-ideas prompts.
  """
  @spec extract_title(String.t() | nil) :: String.t()
  def extract_title(content) do
    content_str =
      case content do
        nil -> ""
        other -> to_string(other)
      end

    content1 = String.replace(content_str, "**", "")
    content2 = Regex.replace(~r/^Title:\s*/i, content1, "")
    first_line = content2 |> String.split("\n") |> Enum.at(0) |> to_string()
    stripped = Regex.replace(~r/^\s*[#]{1,6}\s*/, first_line, "")
    String.trim(stripped)
  end

  @doc """
  Builds a prompt for a rigorous deep dive aimed at advanced learners.

  Parameters:
  - context: The current context block.
  - topic: Topic to deep dive into.
  """
  @spec deep_dive(String.t(), String.t()) :: String.t()
  def deep_dive(context, topic) do
    @style <>
      "\n\n" <>
      """
      Inputs: #{context}, #{topic}
      Output (~280–420 words):
      ## [Precise title]
      - One-sentence statement of what it is and when it applies.

      ### Deep dive
      - Core explanation (1–2 short paragraphs): mechanism, key assumptions, applicability.
      - (Optional) Nuance: 1–2 bullets with caveats/edge cases.
      """
  end

  # -- Private helpers --------------------------------------------------------

  @spec needs_default_selection_schema?(String.t()) :: boolean()
  defp needs_default_selection_schema?(selection) do
    not Regex.match?(
      ~r/(^|\n)Output\s*\(|(^|\n)##\s|(^|\n)###\s|Return only|Headings?:|Subsections?:/im,
      selection
    )
  end

  @spec default_selection_schema() :: String.t()
  defp default_selection_schema do
    """
    Output (markdown):
    ## [Short, descriptive title]
    - Paraphrase (1–2 sentences) of the selection in your own words.

    ### Why it matters here
    - Claims and evidence (2–3 bullets).
    - Assumptions/definitions you’re relying on (1–2 bullets).
    - Implications for the current context (1–2 bullets).
    - Limitations or alternative readings (1–2 bullets).

    ### Next steps
    - Follow‑up questions (1–2).

    Constraints: ~180–260 words.
    """
  end
end
