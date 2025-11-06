defmodule Dialectic.Responses.Prompts do
  @moduledoc """
  Pure prompt builders for LLM interactions.

  This module isolates all prompt text generation from any side effects
  (no I/O, no network, no process messaging). It enables simple, direct
  unit tests against the exact strings that will be sent to a model.

  Typical usage in calling code:
    question = Prompts.explain(context, topic) |> Prompts.wrap_with_style()
    # ...send `question` to your queue / LLM client

  You can also unit test each function directly by asserting on the returned strings.
  """

  @style """
  You are teaching a curious beginner toward university-level mastery.
  - Start with intuition, then add precise definitions and assumptions.
  - Prefer causal/mechanistic explanations.
  - Use short paragraphs and well-structured bullets. Avoid over-fragmented checklists.
  - If context is insufficient, say what’s missing and ask one clarifying question.
  - Prefer info from the provided Context; label other info as "Background".
  - Avoid tables; use headings and bullets only.
  Default to markdown and an H2 title (## …) unless the instruction specifies otherwise. When there is any conflict, follow the question/selection’s format and instructions.
  """

  @doc """
  Returns the global “style” preamble used to guide the LLM’s tone and format.
  """
  @spec style() :: String.t()
  def style, do: @style

  @doc """
  Prepends the global style preamble to the given prompt/question.

  This mirrors how prompts are sent today: `style <> "\\n\\n" <> question`.
  """
  @spec wrap_with_style(String.t()) :: String.t()
  def wrap_with_style(question), do: @style <> "\n\n" <> question

  @doc """
  Builds a prompt that explains a single topic for a first-time learner.

  Parameters:
  - context: Text block describing the current node’s context.
  - topic: A short label or the node content that the explanation should focus on.
  """
  @spec explain(String.t(), String.t()) :: String.t()
  def explain(context, topic) do
    """
    Context:
    #{context}

    Task: Teach a first‑time learner aiming for a university‑level understanding of: "#{topic}"

    Output (markdown):
    ## [Short, descriptive title]
    - Short answer (2–3 sentences) giving the core idea and why it matters.

    ### Deep dive
    - Foundations (optional): 1 short paragraph defining key terms and assumptions.
    - Core explanation (freeform): 1–2 short paragraphs weaving the main mechanism and intuition.

    - Nuances: 2–3 bullets on pitfalls, edge cases, or common confusions; include one contrast with a neighboring idea.

    ### Next steps
    - Next questions to explore (1–2).

    Constraints: Aim for depth over breadth; ~220–320 words.
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
    Context:
    #{context}

    Instruction (apply to the context and current node):
    #{selection}

    Audience: first-time learner aiming for university-level understanding.
    """

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
    """
    Context:
    #{context}

    Write a short, beginner-friendly but rigorous argument in support of: "#{claim}"

    Output (markdown):
    ## [Title of the pro argument]
    - Claim (1 sentence).
    - Narrative reasoning (freeform): 1–2 short paragraphs weaving mechanism and intuition.
    - Illustrative example or evidence (1–2 lines).
    - Assumptions and limits (1 line) plus a falsifiable prediction.
    - When this holds vs. when it might not (1 line).

    Constraints: 150–200 words.
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
    """
    Context:
    #{context}

    Write a short, beginner-friendly but rigorous argument against: "#{claim}"
    Steelman the opposing view (represent the strongest version fairly).

    Output (markdown):
    ## [Title of the con argument]
    - Central critique (1 sentence).
    - Narrative reasoning (freeform): 1–2 short paragraphs laying out the critique.
    - Illustrative counterexample or evidence (1–2 lines).
    - Scope and limits (1 line) plus a falsifiable prediction that would weaken this critique.
    - When this criticism applies vs. when it might not (1 line).

    Constraints: 150–200 words.
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
    """
    Context:
    #{context}

    Generate a beginner-friendly list of related but distinct concepts to explore.

    Current idea: "#{current_idea_title}"

    Requirements:
    - Do not repeat or restate the current idea; prioritize diversity and contrasting schools of thought.
    - Include at least one explicitly contrasting perspective (for example, if the topic is behaviourism, include psychodynamics).
    - Audience: first-time learner.

    Output (markdown only; return only the list):
    - Create 3 short subsections with H3 headings:
      ### Different/contrasting approaches
      ### Adjacent concepts
      ### Practical applications
    - Under each heading, list 3–4 bullets.
    - Each bullet: Concept — 1 sentence on why it’s relevant and how it differs; add one named method/author or canonical example if relevant.
    - Use plain language and avoid jargon.

    Return only the headings and bullets; no intro or outro.
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
    """
    Context:
    #{context}

    Task: Produce a rigorous, detailed deep dive into "#{topic}" for an advanced learner progressing toward research-level understanding.

    Output (markdown):
    ## [Precise title]
    - One-sentence statement of what the concept is and when it applies.

    ### Deep dive
    - Core explanation (freeform): 1–2 short paragraphs tracing the main mechanism, key assumptions, and when it applies.

    - Optional nuance: 1–2 bullets on caveats or edge cases, only if it clarifies usage.

    Constraints: Aim for clarity and concision; ~280–420 words.
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
