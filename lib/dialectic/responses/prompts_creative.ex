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
    - Forbidden: tables, inline HTML, images, code, footnotes, custom extensions.

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
      A synthesis between #{sanitize_title(pos1)} and #{sanitize_title(pos2)}.
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
      """
      Pros for #{sanitize_title(claim)}
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
      """
      Cons against #{sanitize_title(claim)}
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
      Related topics to #{sanitize_title(current_idea_title)}, each with a brief rationale.
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
