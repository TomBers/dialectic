defmodule Dialectic.Responses.PromptsStructured do
  @moduledoc """
  Structured-mode prompt builders (v3, simplified).
  Minimal prompts favoring short, structured answers.
  """

  # ---- Helpers ---------------------------------------------------------------

  def system_preamble do
    """
    SYSTEM — Structured Mode

    Persona: A precise lecturer aiming to provide a university level introduction to the topic.

    Global formatting rules (CommonMark strict)
    - Produce valid CommonMark only; do not emit HTML or templates.
    - The first line must be a single H1 title: "# <title>" followed by a blank line.
    - All headings must begin at the start of a new line, use ATX syntax, and include a space after the hashes (e.g., "## Section"). Never place "#" mid-sentence.
    - Insert a blank line before and after headings, lists, and horizontal rules.
    - Use ASCII list markers at the start of a line only: "- Item". Do not use Unicode dashes (– — ‑) for structure.
    - Use horizontal rules as exactly three hyphens on their own line: "---".
    - Do not duplicate titles or create accidental headers inside paragraphs.
    - Return only Markdown content; no metadata. Use code fences only when the user requests code.
    - Structure the response as a document to be displayed on a webpage.
    - Start with a concise title (# <title>), then an introductory paragraph.
    - Prefer sections over long lists; use Markdown features appropriately.
    - Keep to about 500 words unless asked otherwise.

    Style for structured mode
    - Precise, concise, neutral.
    - Define key terms briefly when they first appear.
    - Prefer concrete, verifiable statements over anecdotes.
    - Stick to the user's scope; avoid digressions.
    - Try and keep the response concise and focused, aim for a maximum of 500 words.

    """
  end

  defp fence(label, text) do
    """
    ### #{label}
    ```text
    #{text}
    ```
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

  # ---- Templates -------------------------------------------------------------

  @doc """
  Teach a first-time learner about `topic`, grounded in `context`.
  """
  @spec explain(String.t(), String.t()) :: String.t()
  def explain(context, topic) do
    join_blocks([
      fence("Context", context),
      fence("Topic", topic),
      """
      Explain: #{sanitize_title(topic)}
      """
    ])
  end

  @doc """
  Apply a `selection_text` instruction to the current `context`.
  """
  @spec selection(String.t(), String.t()) :: String.t()
  def selection(context, selection_text) do
    join_blocks([
      fence("Context", context),
      fence("Selection", selection_text),
      """
      Explain #{sanitize_title(selection_text)}
      """
    ])
  end

  @doc """
  Synthesize two positions (`pos1`, `pos2`) with contexts `context1`, `context2`.
  """
  @spec synthesis(String.t(), String.t(), String.t(), String.t()) :: String.t()
  def synthesis(context1, context2, pos1, pos2) do
    join_blocks([
      fence("Context A", context1),
      fence("Context B", context2),
      """
      A narrative synthesis between #{sanitize_title(pos1)} and #{sanitize_title(pos2)}.
      """
    ])
  end

  @doc """
  Write a short, rigorous argument in support of `claim`, grounded in `context`.
  """
  @spec thesis(String.t(), String.t()) :: String.t()
  def thesis(context, claim) do
    join_blocks([
      fence("Context", context),
      """
      Write the Pros for #{sanitize_title(claim)}.

      Requirements:
      - Start with the H2 heading "## Pros".
      - Use 3–5 concise bullet points (no long paragraphs).
      - Each bullet should be one clear advantage with a brief, concrete rationale.
      """
    ])
  end

  @doc """
  Write a short, rigorous argument against `claim` (steelman first), grounded in `context`.
  """
  @spec antithesis(String.t(), String.t()) :: String.t()
  def antithesis(context, claim) do
    join_blocks([
      fence("Context", context),
      """
      Write the Cons for #{sanitize_title(claim)}.

      Requirements:
      - Start with the H2 heading "## Cons".
      - Use 3–5 concise bullet points (no long paragraphs).
      - Each bullet should be one clear drawback with a brief, concrete rationale.
      """
    ])
  end

  @doc """
  Generate adjacent concepts to `current_idea_title`, grounded in `context`.
  """
  @spec related_ideas(String.t(), String.t()) :: String.t()
  def related_ideas(context, current_idea_title) do
    join_blocks([
      fence("Context", context),
      """
      Provide 3–4 related topics to #{sanitize_title(current_idea_title)}, each with a brief rationale.
      """
    ])
  end

  @doc """
  Deep dive into `topic` for advanced learners, grounded in `context`.
  """
  @spec deep_dive(String.t(), String.t()) :: String.t()
  def deep_dive(context, topic) do
    join_blocks([
      fence("Context", context),
      """
      Write a deep dive on #{sanitize_title(topic)}. Feel free to go beyond the previous word limits, write enough to understand the topic.
      """
    ])
  end
end
