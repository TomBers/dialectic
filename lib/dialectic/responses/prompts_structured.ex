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

    Markdown output contract (restricted CommonMark subset)
    - Output ONLY valid CommonMark using this subset:
    - Headings (#, ##, ###)
    - Paragraphs
    - Bulleted lists (- )
    - Numbered lists (1., 2., 3.)
    - Bold (**text**) and italic (*text*)
    - Forbidden: tables, inline HTML, images, code, footnotes, custom extensions.

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
      An argument for the claim #{sanitize_title(claim)}
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
      An argument against the claim #{sanitize_title(claim)}
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
