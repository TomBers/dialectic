defmodule Dialectic.Responses.PromptsStructured do
  @moduledoc """
  Structured-mode prompt builders (v2).
  Pure functions that return the exact prompt string to send to an LLM.

  Design:
  - System preamble (shared) + task-specific Output Contract.
  - Deterministic section headings for consistent parsing and UX.
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
    SYSTEM — Structured Mode

    Role & Persona
    - A precise lecturer: efficient, neutral, mechanistic. No anecdotes or hype.

    Global Formatting (GitHub-Flavored Markdown only)
    - Output valid GFM only (no HTML/JSON).
    - Put a blank line before every heading and before every list.
    - Prefer short paragraphs over lists; only use a list if the section explicitly asks for one.
    - Any list ≤ 5 bullets, one level only (no nesting).
    - Each bullet is a single sentence (≤ 25 words).
    - Do not use “Label:” bullets. If a label is needed, write a level-4 heading (#### Label) and follow with 1–2 sentence paragraph(s).
    - No mid-sentence headings; use real newlines (not the literal "\\n").
    - No tables or emojis.

    Hard Rules
    - Never show internal reasoning or a checklist; output conclusions only.
    - Use exact section headings from the Output Contract; do not add, remove, or rename sections.
    - Keep sentences short (≈ 8–18 words) unless a section explicitly permits longer.

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
    - Does the output start with the required H2 title?
    - Are all required sections present, in order, with exact headings?
    - Are bullet and list limits respected? (≤ 5 bullets; one level; ≤ 25 words per bullet)
    - Are first-use symbols/terms glossed briefly?
    - Is at least one limit/failure mode included when relevant?
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
  Teach a first-time learner about `topic`, grounded in `context`.
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
        - Sections (exact order, exact headings):

          ### TL;DR (2 sentences max)
          - Core idea and why it matters.

          ### Definitions & Assumptions (3–5 bullets, one sentence each, ≤ 25 words)
          - Define key terms; state assumptions and scope.

          ### Mechanism & Intuition (2 short paragraphs, ≤ 90 words each)
          - First paragraph: intuition.
          - Second paragraph: causal steps; gloss each symbol on first use.

          ### Nuances & Limits (3 bullets, one sentence each, ≤ 25 words)
          - Edge cases, pitfalls, or contrasts.

          ### One next step (1 bullet, one sentence, ≤ 25 words)
          - A simple, actionable follow-up for the learner.
        """,
        silent_checklist(),
        """
        ## Explain: #{topic}

        ### TL;DR (2 sentences max)

        -

        ### Definitions & Assumptions (3–5 bullets, one sentence each, ≤ 25 words)

        -
        -
        -

        ### Mechanism & Intuition

        [Write two short paragraphs.]

        ### Nuances & Limits

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
  Apply a `selection_text` instruction to the current `context`.
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
        - Sections (exact order):

          ### Paraphrase (1–2 sentences)
          - Restate the selection precisely.

          ### Why it matters here (3 bullets, one sentence each, ≤ 25 words)
          - Claims/evidence specific to the given context.

          ### Assumptions (2 bullets, one sentence each, ≤ 25 words)
          - Preconditions for the selection to hold.

          ### Implications (2 bullets, one sentence each, ≤ 25 words)
          - Concrete outcomes or decisions.

          ### Limitations & Alternatives (2 bullets, one sentence each, ≤ 25 words)
          - Where it may fail; viable alternatives.
        """,
        silent_checklist(),
        """
        ## Apply: #{selection_text}

        ### Paraphrase (1–2 sentences)

        -

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
  Synthesize two positions (`pos1`, `pos2`) with contexts `context1`, `context2`.
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
        - Sections (exact order):

          ### Relationship (2 sentences)
          - Concise statement of overlap vs. divergence.

          ### Common Ground (2–3 bullets, one sentence each, ≤ 25 words)
          - Shared assumptions or compatible mechanisms.

          ### Key Tensions (3 bullets, one sentence each, ≤ 25 words)
          - Assumption clashes; trade-offs; boundary conditions.

          ### Reconciliation / Choice (1 short paragraph, ≤ 110 words)
          - When to prefer A, B, or a hybrid; state decision criteria.

          ### Open Questions (2 bullets, one sentence each, ≤ 25 words)
          - Honest unknowns or empirical tests.
        """,
        silent_checklist(),
        """
        ## #{title}

        ### Relationship

        -

        ### Common Ground

        -
        -
        -

        ### Key Tensions

        -
        -
        -

        ### Reconciliation / Choice

        [Write one short paragraph.]

        ### Open Questions

        -
        -
        """
      ])
    end
  end

  @doc """
  Write a short, rigorous argument in support of `claim`, grounded in `context`.
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
        - Sections (exact order):

          ### Claim (1 sentence)
          - Exact proposition being defended.

          ### Reasons (3 bullets, one sentence each, ≤ 25 words)
          - Each reason and why it supports the claim.

          ### Evidence / Examples (2 bullets, one sentence each, ≤ 25 words)
          - Concrete facts, cases, or citations (label outside context as "Background").

          ### Counterarguments & Rebuttals (2 bullets, one sentence each, ≤ 25 words)
          - Strong opposing points and succinct responses.

          ### Assumptions, Limits, Prediction (3 bullets, one sentence each, ≤ 25 words)
          - Key assumption; boundary; a falsifiable prediction.
        """,
        silent_checklist(),
        """
        ## Argue for: #{claim}

        ### Claim

        -

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
  Write a short, rigorous argument against `claim` (steelman first), grounded in `context`.
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
        - Sections (exact order):

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

        ### Central Critique

        -

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
  Generate adjacent concepts to `current_idea_title`, grounded in `context`.
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
        - Start with: ## Adjacent to: #{current_idea_title}
        - Sections (exact order):

          ### Adjacent concepts
          - Provide 3–4 concepts. For each concept:
            Use a level-4 heading with the concept name, then a 1–2 sentence paragraph (≤ 50 words) explaining relevance. No lists inside items.
        """,
        silent_checklist(),
        """
        ## Adjacent to: #{current_idea_title}

        ### Adjacent concepts

        #### [Concept 1]
        [Write 1–2 sentences on relevance.]

        #### [Concept 2]
        [Write 1–2 sentences on relevance.]

        #### [Concept 3]
        [Write 1–2 sentences on relevance.]

        #### [Concept 4]
        [Write 1–2 sentences on relevance.]
        """
      ])
    end
  end

  @doc """
  Deep dive into `topic` for advanced learners, grounded in `context`.
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
        - Sections (exact order):

          ### One-liner (1 sentence)
          - What it is and when it applies.

          ### Core explanation (2–3 short paragraphs, ≤ 100 words each)
          - Mechanism; assumptions; applicability. Gloss symbols on first use.

          ### Nuance (2 bullets, one sentence each, ≤ 25 words)
          - Caveats, edge cases, or failure modes.

          ### When to use vs. avoid (2 bullets, one sentence each, ≤ 25 words)
          - Clear decision cues.
        """,
        silent_checklist(),
        """
        ## Deep dive: #{topic}

        ### One-liner

        -

        ### Core explanation

        [Write 2–3 short paragraphs.]

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
