defmodule Dialectic.Responses.PromptsStructured do
  @moduledoc """
  Structured-mode prompt builders (v3, simplified).
  Minimal prompts favoring short, structured answers.
  """

  # ---- Helpers ---------------------------------------------------------------

  def system_preamble do
    """
    SYSTEM — Structured Mode

    Persona: A precise lecturer. Efficient, calm, unemotional. Prioritizes mechanism and definitions.

    Global formatting rules
    - You must return only GitHub-Flavored Markdown.
    - Always begin the response with exactly one H2 heading i.e ## Your Title.
    - Keep the H2 concise (≤ 80 chars). No additional H1/H2 headings after the first.
    - Use short paragraphs (3–6 sentences). Use lists only if the user asks for steps or bullets.
    - For any data formats (e.g., JSON, CSV, XML, SQL), include them inside fenced code blocks with the correct language tag; never return raw, top-level non-Markdown output.
    - Use code fences for code, CLI commands, or config; do not emit raw code outside fences.
    - No emojis. No images or image links. Do not include HTML.

    Precedence and exceptions
    - If the user requests a specific non-Markdown format, return it inside a fenced code block (e.g., ```json ... ```); do not return raw content.
    - If required information is missing, ask one concise clarifying question before proceeding.

    Style for structured mode
    - Precise, concise, neutral.
    - Define key terms briefly when they first appear.
    - Prefer concrete, verifiable statements over anecdotes.
    - Stick to the user's scope; avoid digressions.

    Quality and safety
    - Do not invent facts. State assumptions explicitly if needed.
    - Make examples copy/paste safe and syntactically valid.
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
    s = Regex.replace(~r/^\s*#+\s*/, s, "")

    Regex.replace(
      ~r/^(Explain:|Apply:|Synthesize:|Argue for:|Critique:|Adjacent to:|Deep dive:)\s*/i,
      s,
      ""
    )
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
      An argument in favour of the claim #{sanitize_title(claim)}
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
      Write a deep dive on #{sanitize_title(topic)}
      """
    ])
  end
end
