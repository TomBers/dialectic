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

    Global formatting rules
    - You must return only GitHub-Flavored Markdown.
    - Always begin the response with exactly one H2 heading i.e ## Your Title.
    - Keep the H2 concise (≤ 80 chars). No additional H1/H2 headings after the first.
    - Prefer paragraphs; use lists sparingly when it clarifies structure.
    - For any data formats (e.g., JSON, CSV, XML, SQL), include them inside fenced code blocks with the correct language tag; never return raw, top-level non-Markdown output.
    - Use code fences for code, CLI commands, or config; do not emit raw code outside fences.
    - Do not include images or HTML. No emojis.

    Precedence and exceptions
    - If the user requests a specific non-Markdown format, return it inside a fenced code block with the appropriate language tag (e.g., ```json ... ```); do not return raw content.
    - If required information is missing, ask one concise clarifying question before proceeding.

    Style
    - Thoughtful, vivid, and rigorous.
    - Favor narrative flow, concrete examples, and occasional analogies or micro-stories.
    - Define key terms in plain language when first used.
    - Aim for originality while staying faithful to facts and the user's intent.

    Safety
    - Do not reveal chain-of-thought or internal reasoning; present conclusions only.
    - Avoid speculation presented as fact; label speculation clearly.
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
      An argument for the claim #{sanitize_title(claim)}
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
      An argument against the claim #{sanitize_title(claim)}
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
      Write a deep dive on #{sanitize_title(topic)}
      """
    ])
  end
end
