defmodule Dialectic.Responses.PromptsCreative do
  @moduledoc """
  Creative prompt builders for LLM interactions.

  This module mirrors the `Dialectic.Responses.PromptsStructured` surface but guides the model
  toward a freer, more narrative and exploratory style. The functions are pure and
  return the final prompt text (style preamble included), so they are easy to test
  and swap in based on a user-selected mode.
  """

  @style """
  You are a creative, insightful guide who blends rigor with imagination.
  - Start with an evocative hook, then unfold the idea with clear reasoning.
  - Feel free to use analogy, micro-stories, or cross-disciplinary links.
  - Prefer short, vivid paragraphs; mix bullets sparingly for emphasis.
  - If context is thin, name the missing piece and pose one provocative question.
  - Prefer information from the provided Context; label other information as "Background".
  - Use markdown; headings are welcome but need not be rigid. Flow and narrative are valued.
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

      Task: Offer a spirited, narrative exploration of: "#{topic}"

      Output (markdown):
      ## [Evocative title capturing the idea’s spark]
      A short spark (2–3 sentences) that makes the core idea feel alive.

      ### Exploration
      Freeform narrative (1–3 short paragraphs) that blends intuition, examples, and one precise definition in plain language.
      - If helpful, add 1–2 bullets for surprising connections or tensions.
      - Use metaphor or analogy only when it sharpens understanding.

      ### Next moves
      1–2 questions or experiments the learner could try next—concrete and playful.
      """
  end

  @doc """
  Builds a prompt that applies a selection/instruction to the current context, with a freer tone.

  If the selection text does not specify a format, a gentle creative guide is appended.
  """
  @spec selection(String.t(), String.t()) :: String.t()
  def selection(context, selection) do
    base = """
    Context:
    #{context}

    Instruction (apply to the context and current node):
    #{selection}

    Audience: a curious learner open to analogy and narrative, but wanting substance.
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
      Context:
      #{context}

      Write a brief, creative yet rigorous argument in support of: "#{claim}"

      Output (markdown):
      ## [A vivid title for the pro argument]
      - Claim in plain words (1 sentence).
      - Story or mechanism: 1–2 short paragraphs mixing intuition and a concrete example.
      - A named assumption in plain language and what it buys us.
      - When this tends to hold vs. where it thins out (1–2 lines).
      - One falsifiable sign that would make you update.

      Keep it warm, clear, and specific.
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
      Context:
      #{context}

      Write a brief, creative yet rigorous argument against: "#{claim}"
      Steelman the opposing view first (present its best version), then critique.

      Output (markdown):
      ## [A vivid title for the con argument]
      - Steelman: the strongest case for the view (2–3 sentences).
      - Critique: 1–2 short paragraphs with concrete counterexample or mechanism-level concerns.
      - Scope: 1–2 lines on where the critique applies and where it shouldn’t.
      - One observation that would soften this critique.

      Keep it fair-minded, curious, and precise.
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
      Context:
      #{context}

      Generate a creative list of related but distinct concepts worth exploring next.

      Current idea: "#{current_idea_title}"

      Output (markdown):
      - 8–12 bullets mixing adjacent concepts, contrasting approaches, and practical angles.
      - For each: Name — one bright line on why it matters here; add one canonical author, method, or example if relevant.
      - Prefer diversity over repetition; include at least one sharp contrast.

      Keep bullets short and scannable; avoid jargon.
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
      Context:
      #{context}

      Task: Compose a narrative deep dive into "#{topic}" that blends intuition,
      one crisp definition, and a few surprising connections.

      Output (markdown):
      ## [A precise yet evocative title]
      - Opening hook (1–2 sentences): why this topic is alive right now.
      - Core explanation: 1–3 short paragraphs tracing the mechanism in plain language.
      - Connections: 2–4 bullets linking to neighboring ideas, methods, or pitfalls.
      - Optional: a brief micro-story, example, or thought experiment.

      Aim for clarity with personality; substance over flourish.
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
