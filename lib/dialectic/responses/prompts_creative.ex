defmodule Dialectic.Responses.PromptsCreative do
  @moduledoc """
  Creative-mode prompt builders (v3, simplified).
  Minimal prompts favoring longer, more expressive answers.
  """

  # ---- Helpers ---------------------------------------------------------------

  def system_preamble do
    """
    SYSTEM — Creative Mode

    Persona: A thoughtful guide. Curious, vivid, and rigorous.

    Markdown output contract (restricted CommonMark subset)
    - Output ONLY valid CommonMark using this subset:
      - Headings (#, ##, ###)
      - Paragraphs
      - Bulleted lists (- )
      - Numbered lists (1., 2., 3.)
      - Bold (**text**) and italic (*text*)

    - Forbidden: tables, code, inline HTML, images, footnotes, custom extensions.

    Document structure
    - The first line must be a single H1 title: "# <title>" followed by a blank line.
    - Insert a blank line before and after headings and lists.
    - Use ASCII list markers only; do not use Unicode dashes for structure.
    - Return only Markdown content; no metadata.

    Streaming-friendly guidance
    - Prefer completing small units (short paragraphs, whole list items, complete code blocks) before starting new sections.
    - If you start a code fence, close it promptly.
    - Avoid leaving headings without at least one following paragraph.

    Style
    - Thoughtful, vivid, and rigorous.
    - Favor narrative flow, concrete examples, and occasional analogies or micro-stories.
    - Aim for originality while staying faithful to facts and the user's intent.
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
    |> Enum.reject(&(&1 == nil or &1 == ""))
    |> Enum.join("\n\n")
  end

  defp sanitize_title(title) do
    s = to_string(title) |> String.trim()
    Regex.replace(~r/^\s*#+\s*/, s, "")
  end

  # ---- Templates -------------------------------------------------------------

  @doc """
  Narrative exploration for a curious learner.
  """
  @spec explain(String.t(), String.t()) :: String.t()
  def explain(context, topic) do
    join_blocks([
      fence("Context", context),
      """
      Explain: #{sanitize_title(topic)}
      """
    ])
  end

  @doc """
  Apply a selection/instruction with a freer tone.
  """
  @spec selection(String.t(), String.t()) :: String.t()
  def selection(context, selection_text) do
    join_blocks([
      fence("Context", context),
      """
      Explain: #{sanitize_title(selection_text)}
      """
    ])
  end

  @doc """
  Creative synthesis using a narrative bridge and useful boundaries.
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
  Argue in favor with lively but grounded narrative voice.
  """
  @spec thesis(String.t(), String.t()) :: String.t()
  def thesis(context, claim) do
    join_blocks([
      fence("Context", context),
      fence("Claim", claim),
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
  Argue against with fairness and imaginative clarity.
  """
  @spec antithesis(String.t(), String.t()) :: String.t()
  def antithesis(context, claim) do
    join_blocks([
      fence("Context", context),
      fence("Target Claim", claim),
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
  Generate creative next explorations and practical sparks.
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
  Narrative deep dive with an arc and a clean definition.
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
