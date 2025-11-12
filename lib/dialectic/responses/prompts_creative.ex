defmodule Dialectic.Responses.PromptsCreative do
  @moduledoc """
  Creative-mode prompt builders (v2).
  Pure functions that return the exact prompt string to send to an LLM.

  Design:
  - System preamble (shared) + task-specific Output Contract.
  - Freer narrative style, but deterministic section headings.
  - Single-question fallback if required inputs are missing.
  - GitHub-Flavored Markdown formatting discipline encoded in the preamble.
  """

  # ---- Helpers ---------------------------------------------------------------

  defp fence(label, text) do
    """
    ### #{label}
    ```text
    #{text}
    ```
    """
  end

  defp system_preamble do
    """
    SYSTEM — Creative Mode

    Role & Persona
    - A thoughtful guide: curious, vivid, and rigorous. Uses analogy or a micro-story when it clarifies.

    Global Formatting (GitHub-Flavored Markdown only)
    - Output valid GFM only (no HTML/JSON).
    - Put a blank line before every heading and before every list.
    - Prefer short paragraphs over lists; only use a list if the section explicitly asks for one.
    - Any list ≤ 5 bullets, one level only (no nesting).
    - Each bullet is a single sentence (≤ 25 words).
    - Do not use “Label:” bullets. If a label is needed, write a level-4 heading (#### Label) and follow with 1–2 sentence paragraph(s).
    - No mid-sentence headings; use real newlines (not the literal "\\n").
    - No tables or emojis.

    Style
    - Varied cadence: mix short punchy lines with longer arcs. Hooks welcome.
    - A single, well-placed rhetorical question is allowed per major section.
    - Define crucial terms early, in plain language. Gloss symbols on first use.
    - Mark non-context information as **Background** (or **Background — tentative** if low confidence).

    Hard Rules
    - Never show internal reasoning or a checklist; output conclusions only.
    - Start with the required H2 title and include the exact sections listed in the Output Contract.
    - Do not add, remove, or rename sections beyond the contract.

    Direct Answer
    - Include a `#### Answer` heading near the top with a one-sentence direct answer or takeaway.

    Missing Inputs
    - If any required input is empty or clearly missing, ignore the normal format and produce:
      ## Clarification needed

      - Ask one concise question to unblock progress (single bullet, ≤ 25 words).
    """
  end

  defp silent_checklist do
    """
    (Do not print this. Use it silently.)
    Checklist:
    - Required H2 present? (exact title)
    - Sections present in exact order with exact headings?
    - Bullet limits respected? (≤ 5; one level; ≤ 25 words)
    - Key terms defined early; symbols glossed?
    - Optional rhetorical questions kept to ≤ 1 per major section?
    - At least one limit/failure mode included when relevant?
    """
  end

  defp join_blocks(blocks) do
    blocks
    |> Enum.reject(&(&1 == nil or &1 == ""))
    |> Enum.join("\n\n")
  end

  defp missing?(val), do: val |> to_string() |> String.trim() == ""

  # ---- Templates -------------------------------------------------------------

  @doc """
  Narrative exploration for a curious learner.
  """
  @spec explain(String.t(), String.t()) :: String.t()
  def explain(context, topic) do
    if missing?(topic) or missing?(context) do
      join_blocks([
        system_preamble(),
        fence("Context", context),
        fence("Topic", topic),
        """
        Output Contract:
        - If any required input is missing, output only:

          ## Clarification needed

          - Ask one concise question to unblock progress (single bullet, ≤ 25 words).
        """,
        silent_checklist()
      ])
    else
      join_blocks([
        system_preamble(),
        fence("Context", context),
        fence("Topic", topic),
        """
        Output Contract
        - Start with: ## Explain: #{topic}
        - Order and exact headings:

          #### Answer
          - One sentence that directly answers the question or states the takeaway.

          ### Hook & Definition
          - 1–2 lines for an evocative hook.
          - 1 line plain-language definition.

          ### Story-driven explanation
          - Two short paragraphs (≤ 90 words each): intuition; then how it works in practice.
          - May include one rhetorical question total.

          ### Subtleties (2–3 bullets, one sentence each, ≤ 25 words)
          - Pitfalls, contrasts, edge cases; include at least one limit/failure mode.

          ### One next step (1 bullet, one sentence, ≤ 25 words)
          - A simple action or question to explore next.
        """,
        silent_checklist(),
        """
        ## Explain: #{topic}

        #### Answer
        [One sentence.]

        ### Hook & Definition
        [1–2 lines of hook.]
        [1 line definition.]

        ### Story-driven explanation
        [Paragraph 1: intuition.]
        [Paragraph 2: how it works.]

        ### Subtleties
        -
        -
        -

        ### One next step
        -
        """
      ])
    end
  end

  @doc """
  Apply a selection/instruction with a freer tone.
  """
  @spec selection(String.t(), String.t()) :: String.t()
  def selection(context, selection_text) do
    if missing?(selection_text) or missing?(context) do
      join_blocks([
        system_preamble(),
        fence("Context", context),
        fence("Selection", selection_text),
        """
        Output Contract:
        - If any required input is missing, output only:

          ## Clarification needed

          - Ask one concise question to unblock progress (single bullet, ≤ 25 words).
        """,
        silent_checklist()
      ])
    else
      join_blocks([
        system_preamble(),
        fence("Context", context),
        fence("Selection", selection_text),
        """
        Output Contract
        - Start with: ## Apply: #{selection_text}
        - Order and exact headings:

          #### Answer
          - One sentence stating the action/result.

          ### Paraphrase (1–2 sentences)
          - Restate the instruction precisely and in plain terms.

          ### Why it matters here (3 bullets, one sentence each, ≤ 25 words)
          - Context-specific benefits or evidence.

          ### Assumptions (2 bullets, one sentence each, ≤ 25 words)
          - Preconditions or definitions required.

          ### Implications (2 bullets, one sentence each, ≤ 25 words)
          - Concrete outcomes or decisions.

          ### Limitations & Alternatives (2 bullets, one sentence each, ≤ 25 words)
          - Where it may fail; viable alternatives.
        """,
        silent_checklist(),
        """
        ## Apply: #{selection_text}

        #### Answer
        [One sentence.]

        ### Paraphrase (1–2 sentences)
        [1–2 sentences.]

        ### Why it matters here
        -
        -
        -

        ### Assumptions
        -
        -

        ### Implications
        -
        -

        ### Limitations & Alternatives
        -
        -
        """
      ])
    end
  end

  @doc """
  Creative synthesis using a narrative bridge and useful boundaries.
  """
  @spec synthesis(String.t(), String.t(), String.t(), String.t()) :: String.t()
  def synthesis(context1, context2, pos1, pos2) do
    if missing?(context1) or missing?(context2) or missing?(pos1) or missing?(pos2) do
      join_blocks([
        system_preamble(),
        fence("Context A", context1),
        fence("Context B", context2),
        fence("Position A", pos1),
        fence("Position B", pos2),
        """
        Output Contract:
        - If any required input is missing, output only:

          ## Clarification needed

          - Ask one concise question to unblock progress (single bullet, ≤ 25 words).
        """,
        silent_checklist()
      ])
    else
      title = "Synthesize: #{pos1} × #{pos2}"

      join_blocks([
        system_preamble(),
        fence("Context A", context1),
        fence("Context B", context2),
        fence("Position A", pos1),
        fence("Position B", pos2),
        """
        Output Contract
        - Start with: ## #{title}
        - Order and exact headings:

          #### Answer
          - One sentence capturing the principal reconciliation or trade-off.

          ### Narrative bridge
          - 1–2 short paragraphs (≤ 100 words each) on common ground and tensions; make assumptions explicit.
          - May include one rhetorical question total.

          ### Bridge or boundary (1 short paragraph, ≤ 110 words)
          - A synthesis or clear boundary with decision criteria; include one testable prediction.

          ### When each view is stronger (3 bullets, one sentence each, ≤ 25 words)
          - Contexts where A wins, B wins, or a hybrid wins.

          ### Open Questions (2 bullets, one sentence each, ≤ 25 words)
          - Honest unknowns or empirical tests.
        """,
        silent_checklist(),
        """
        ## #{title}

        #### Answer
        [One sentence.]

        ### Narrative bridge
        [Paragraph 1.]
        [Paragraph 2.]

        ### Bridge or boundary
        [One short paragraph.]

        ### When each view is stronger
        -
        -
        -

        ### Open Questions
        -
        -
        """
      ])
    end
  end

  @doc """
  Argue in favor with lively but grounded narrative voice.
  """
  @spec thesis(String.t(), String.t()) :: String.t()
  def thesis(context, claim) do
    if missing?(claim) or missing?(context) do
      join_blocks([
        system_preamble(),
        fence("Context", context),
        fence("Claim", claim),
        """
        Output Contract:
        - If any required input is missing, output only:

          ## Clarification needed

          - Ask one concise question to unblock progress (single bullet, ≤ 25 words).
        """,
        silent_checklist()
      ])
    else
      join_blocks([
        system_preamble(),
        fence("Context", context),
        fence("Claim", claim),
        """
        Output Contract
        - Start with: ## Argue for: #{claim}
        - Order and exact headings:

          #### Answer
          - One sentence stating the position.

          ### Claim (1 sentence)
          - Exact proposition being defended.

          ### Reasons (3 bullets, one sentence each, ≤ 25 words)
          - Each reason and why it supports the claim.

          ### Evidence / Examples (2 bullets, one sentence each, ≤ 25 words)
          - Concrete facts, cases, or citations (label outside context as **Background**).

          ### Counterarguments & Rebuttals (2 bullets, one sentence each, ≤ 25 words)
          - Strong opposing points and succinct responses.

          ### Assumptions, Limits, Prediction (3 bullets, one sentence each, ≤ 25 words)
          - Key assumption; boundary; a falsifiable prediction.
        """,
        silent_checklist(),
        """
        ## Argue for: #{claim}

        #### Answer
        [One sentence.]

        ### Claim
        [One sentence.]

        ### Reasons
        -
        -
        -

        ### Evidence / Examples
        -
        -

        ### Counterarguments & Rebuttals
        -
        -

        ### Assumptions, Limits, Prediction
        -
        -
        """
      ])
    end
  end

  @doc """
  Argue against with fairness and imaginative clarity.
  """
  @spec antithesis(String.t(), String.t()) :: String.t()
  def antithesis(context, claim) do
    if missing?(claim) or missing?(context) do
      join_blocks([
        system_preamble(),
        fence("Context", context),
        fence("Target Claim", claim),
        """
        Output Contract:
        - If any required input is missing, output only:

          ## Clarification needed

          - Ask one concise question to unblock progress (single bullet, ≤ 25 words).
        """,
        silent_checklist()
      ])
    else
      join_blocks([
        system_preamble(),
        fence("Context", context),
        fence("Target Claim", claim),
        """
        Output Contract
        - Start with: ## Critique: #{claim}
        - Order and exact headings:

          #### Answer
          - One sentence stating the central critique.

          ### Central Critique (1 sentence)
          - What is being argued against and why.

          ### Reasons (3 bullets, one sentence each, ≤ 25 words)
          - How each reason undermines the claim.

          ### Evidence / Counterexamples (2 bullets, one sentence each, ≤ 25 words)
          - Concrete disconfirming facts/cases.

          ### Steelman & Response (2 bullets, one sentence each, ≤ 25 words)
          - Strongest pro-claim point(s) and why insufficient.

          ### Scope, Limit, Prediction (3 bullets, one sentence each, ≤ 25 words)
          - Where the critique applies; boundary; a risky prediction.
        """,
        silent_checklist(),
        """
        ## Critique: #{claim}

        #### Answer
        [One sentence.]

        ### Central Critique
        [One sentence.]

        ### Reasons
        -
        -
        -

        ### Evidence / Counterexamples
        -
        -

        ### Steelman & Response
        -
        -

        ### Scope, Limit, Prediction
        -
        -
        """
      ])
    end
  end

  @doc """
  Generate creative next explorations and practical sparks.
  """
  @spec related_ideas(String.t(), String.t()) :: String.t()
  def related_ideas(context, current_idea_title) do
    if missing?(current_idea_title) or missing?(context) do
      join_blocks([
        system_preamble(),
        fence("Context", context),
        fence("Current Idea", current_idea_title),
        """
        Output Contract:
        - If any required input is missing, output only:

          ## Clarification needed

          - Ask one concise question to unblock progress (single bullet, ≤ 25 words).
        """,
        silent_checklist()
      ])
    else
      join_blocks([
        system_preamble(),
        fence("Context", context),
        fence("Current Idea", current_idea_title),
        """
        Output Contract
        - Start with: ## What to explore next: #{current_idea_title}
        - Order and exact headings:

          #### Answer
          - One sentence stating the next-step takeaway.

          ### Adjacent concepts
          - Provide 3–4 items. For each item:
            Use a level-4 heading with the concept name, then a 1–2 sentence paragraph (≤ 50 words) explaining relevance. No lists inside items.

          ### Practical sparks
          - Provide 3–4 items. For each item:
            Use a level-4 heading with the idea name, then a 1–2 sentence paragraph (≤ 50 words) describing a concrete application.
        """,
        silent_checklist(),
        """
        ## What to explore next: #{current_idea_title}

        #### Answer
        [One sentence.]

        ### Adjacent concepts

        #### [Concept 1]
        [1–2 sentence paragraph.]

        #### [Concept 2]
        [1–2 sentence paragraph.]

        #### [Concept 3]
        [1–2 sentence paragraph.]

        #### [Concept 4]
        [1–2 sentence paragraph.]

        ### Practical sparks

        #### [Application 1]
        [1–2 sentence paragraph.]

        #### [Application 2]
        [1–2 sentence paragraph.]

        #### [Application 3]
        [1–2 sentence paragraph.]

        #### [Application 4]
        [1–2 sentence paragraph.]
        """
      ])
    end
  end

  @doc """
  Narrative deep dive with an arc and a clean definition.
  """
  @spec deep_dive(String.t(), String.t()) :: String.t()
  def deep_dive(context, topic) do
    if missing?(topic) or missing?(context) do
      join_blocks([
        system_preamble(),
        fence("Context", context),
        fence("Concept", topic),
        """
        Output Contract:
        - If any required input is missing, output only:

          ## Clarification needed

          - Ask one concise question to unblock progress (single bullet, ≤ 25 words).
        """,
        silent_checklist()
      ])
    else
      join_blocks([
        system_preamble(),
        fence("Context", context),
        fence("Concept", topic),
        """
        Output Contract
        - Start with: ## Deep dive: #{topic}
        - Order and exact headings:

          #### Answer
          - One sentence direct takeaway.

          ### One-liner (1 sentence)
          - What it is and when it applies.

          ### The arc
          - 2–3 short paragraphs (≤ 100 words each): intuition → mechanism → implications.
          - May include one rhetorical question total.

          ### Nuance (2 bullets, one sentence each, ≤ 25 words)
          - Caveats, edge cases, or failure modes.

          ### When to use vs. avoid (2 bullets, one sentence each, ≤ 25 words)
          - Clear decision cues.
        """,
        silent_checklist(),
        """
        ## Deep dive: #{topic}

        #### Answer
        [One sentence.]

        ### One-liner
        [One sentence.]

        ### The arc
        [Paragraph 1: intuition.]
        [Paragraph 2: mechanism.]
        [Paragraph 3: implications.]

        ### Nuance
        -
        -

        ### When to use vs. avoid
        -
        -
        """
      ])
    end
  end
end
