defmodule Dialectic.Responses.PromptsCreative do
  @moduledoc """
  Creative prompt builders for LLM interactions.

  This module mirrors the `Dialectic.Responses.PromptsStructured` surface but guides the model
  toward a freer, more narrative and exploratory style. The functions are pure and
  return the final prompt text (style preamble included), so they are easy to test
  and swap in based on a user-selected mode.
  """

  @style """
  Persona: A thoughtful guide. Curious, vivid, and rigorous. Uses story and analogy to spark insight.
  Voice & Tone
  - Warm, lively, intellectually honest.
  - Allowed: carefully chosen metaphor, micro-story, second person (“you”).
  - Label any guesswork as “Speculation”.

  Rhythm & Sentence Rules
  - Varied cadence: mix short punchy lines with longer arcs.
  - Hooks welcome; occasional rhetorical question to prime curiosity.
  - Keep paragraphs short (2–4 sentences). Bullets only for emphasis.

  Formatting
  - H2 title encouraged but can be playful.
  - Headings are flexible; narrative flow beats rigid sections.
  - No tables. Sparse italics for emphasis; em dashes allowed.

  Information Hygiene
  - Open with an evocative hook (1–2 lines), then ground with one plain-language definition.
  - Prefer Context. Mark extras as “Background” or “Background — tentative”.
  - If context is thin, name the missing piece and pose one provocative question at the end.

  Signature Moves (use 1–2, not all)
  - **Analogy pivot:** map the concept to a vivid, accurate everyday system.
  - **Micro-story (2–4 lines):** a scene that illustrates the mechanism.
  - **Tension spotlight:** highlight one surprising contrast or trade-off.
  - **Bridge home:** a crisp takeaway that invites a next experiment.

  Language Preferences
  - Concrete imagery over abstraction when it clarifies.
  - Verbs that move: nudge, probe, hedge, snap, drift.
  - Avoid hype or purple prose; delight comes from clarity.

  Red Lines
  - No long lists, no academic throat-clearing.
  - Don’t hide definitions—state one crisp definition early.

  Quality Checks
  - The hook makes the idea feel alive without distorting it.
  - At least one precise definition appears in plain language.
  - Ends with an actionable next step or question.
  """

  @doc """
  Builds a prompt that explains a single topic for a curious learner using a narrative style.

  Parameters:
  - context: Text block describing the current node’s context.
  - topic: A short label or the node content that the explanation should focus on.
  """
  @spec explain(String.t(), String.t()) :: String.t()
  def explain(context, topic) do
    @style <>
      "\n\n" <>
      """
      Context:
      #{context}


      Inputs: #{context}, #{topic}
      Task: Narrative exploration of #{topic}.
      Output (Markdown):
      ## [Evocative title]
      A 2–3 sentence spark.

      ### Exploration
      1–3 short paragraphs blending intuition, one precise plain-language definition, and an example.
      - (Optional) 1–2 bullets for surprising links/tensions.

      ### Next moves
      1–2 playful, concrete questions/experiments.
      """
  end

  @doc """
  Builds a prompt that applies a selection/instruction to the current context, with a freer tone.

  If the selection text does not specify a format, a gentle creative guide is appended.
  """
  @spec selection(String.t(), String.t()) :: String.t()
  def selection(context, selection) do
    base = """
    Inputs: #{context}, #{selection}
    Output (Markdown):
    ## [Inviting heading naming the gist]
    - Paraphrase (2–3 sentences).
    - What matters: 2–4 bullets (claims, assumptions, implications).
    - One alternative angle or tension.
    - One playful next step.
    """

    @style <>
      "\n\n" <>
      if needs_default_selection_schema?(selection) do
        base <>
          """

          Suggested shape (feel free to adapt):
          ## [An inviting heading that names the gist]
          - Paraphrase in your own words (2–3 sentences).
          - What matters here: 2–4 bullets surfacing claims, assumptions, and implications.
          - One alternative angle or tension to keep in mind.

          Close with one playful next step (a question, mini-experiment, or example to find).
          """
      else
        base
      end
  end

  @doc """
  Builds a prompt to synthesize two positions using a narrative bridge and creative contrasts.

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
      Context of first position:
      #{context1}

      Context of second position:
      #{context2}

      Task: Weave a creative synthesis of "#{pos1}" and "#{pos2}" that respects both,
      clarifies where they shine, and proposes a bridge or a useful boundary.

      Output (markdown):
      ## [A title that frames the shared landscape or fruitful tension]
      - Opening image or analogy (1–2 sentences) that frames the relationship.
      - Narrative: 1–3 short paragraphs naming common ground, real points of friction, and what each view explains best.
      - Bridge or boundary: one paragraph proposing a synthesis or a crisp line that keeps both useful.
      - Unresolved: 2 bullets on questions that remain genuinely open.

      End with one actionable test or reading path to explore further.
      """
  end

  @doc """
  Builds a prompt to argue for a claim with a lively but grounded narrative voice.

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
      Output (Markdown):
      ## [Vivid title]
      - Claim in plain words (1 sentence).
      - Story/mechanism (1–2 short paragraphs) with a concrete example.
      - Named assumption and what it buys us.
      - Where it holds vs. thins out (1–2 lines).
      - One falsifiable sign that would change our mind.
      """
  end

  @doc """
  Builds a prompt to argue against a claim with fairness and imaginative clarity.

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
      Output (Markdown):
      ## [Vivid title]
      - Steelman (2–3 sentences).
      - Critique (1–2 short paragraphs) with a concrete counterexample or mechanism-level concern.
      - Scope: 1–2 lines on where it applies vs. shouldn’t.
      - One observation that would soften the critique.
      """
  end

  @doc """
  Builds a prompt to generate a creative list of related and contrasting ideas.

  Parameters:
  - context: The current context block.
  - current_idea_title: Title/label of the current idea.
  """
  @spec related_ideas(String.t(), String.t()) :: String.t()
  def related_ideas(context, current_idea_title) do
    @style <>
      "\n\n" <>
      """
      Inputs: #{context}, #{current_idea_title}
      Output (Markdown):
      - 8–12 bullets mixing adjacent concepts, contrasts, and practical angles.
      - Each: Name — one bright line on why it matters; optional author/method/example.
      - Keep short, scannable, jargon-light; include at least one sharp contrast.
      """
  end

  @doc """
  Builds a prompt for a creative deep dive with a narrative arc.

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
      Output (Markdown):
      ## [Precise yet evocative title]
      - Opening hook (1–2 sentences).
      - Core explanation: 1–3 short paragraphs in plain language.
      - Connections: 2–4 bullets (neighboring ideas, methods, pitfalls).
      - (Optional) Micro-story/example/thought experiment.
      """
  end

  @doc """
  Extracts a concise title from a content block, mirroring the behavior in Prompts.
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

  # -- Private helpers --------------------------------------------------------

  @spec needs_default_selection_schema?(String.t()) :: boolean()
  defp needs_default_selection_schema?(selection) do
    not Regex.match?(
      ~r/(^|\n)Output\s*\(|(^|\n)##\s|(^|\n)###\s|Return only|Headings?:|Subsections?:/im,
      selection
    )
  end
end
