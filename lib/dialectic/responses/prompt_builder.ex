defmodule Dialectic.Responses.PromptBuilder do
  @moduledoc """
  Pure prompt-construction helpers with no side effects.

  This module exists to make the wording of prompts easy to test without
  spinning up processes, touching background job infrastructure, or accessing
  external services.

  It only knows about:
  - The "system style" (base style + per-mode guidance) coming from
    `Dialectic.Responses.Modes`.
  - The question body text that we want the model to answer.

  It does NOT:
  - Reach into a graph.
  - Build "Context:" sections.
  - Enqueue any jobs or talk to APIs.

  Usage:

      alias Dialectic.Responses.PromptBuilder

      # Build a final prompt from a pre-built question body and a mode.
      final = PromptBuilder.compose("Instruction: Answer briefly.", :structured)

      # Build standard question bodies (no context, no IO):
      body = PromptBuilder.question_response("Explain recursion")
      final = PromptBuilder.compose(body, :creative)

  Testing:

  - Tests can assert directly on the exact returned strings for question bodies
    and the composed final prompt. No stubs are needed.
  """

  @doc """
  Compose the final prompt by prefixing the mode's system style
  to the given `question_body`.

  Returns: system_prompt(mode) <> 2 newlines <> question_body
  """
  @spec compose(String.t(), atom() | String.t()) :: String.t()
  def compose(question_body, mode) when is_binary(question_body) do
    Dialectic.Responses.Modes.system_prompt(mode) <> "\n\n" <> question_body
  end

  # ---------------------------
  # Standard question bodies (no context, side-effect free)
  # ---------------------------

  @doc """
  Answer a user's request directly with compact guidance.
  """
  @spec question_response(String.t()) :: String.t()
  def question_response(user_request) when is_binary(user_request) do
    """
    Instruction:
    Start your answer with:
    ## Response
    Answer "#{user_request}" directly with short paragraphs. Length: ~120–220 words. If the topic is abstract, include one concrete example. You may end with a 2–4‑bullet Checklist if it adds value.
    """
  end

  @doc """
  Rewrite a highlighted passage and explain its relevance, with clear fallbacks.
  """
  @spec question_selection(String.t()) :: String.t()
  def question_selection(selection) when is_binary(selection) do
    """
    Instruction (apply to the selection below):
    #{selection}

    Instruction:
    Rewrite the highlighted passage more clearly with one concrete example; then paraphrase why it matters to the current context. If no selection is present, say so and ask for it in one sentence. If the selection is already clear, improve micro‑clarity (shorter sentences, concrete nouns/verbs) rather than expanding.

    Return with these sections:
    ### Rewritten — cleaner phrasing + one concrete example.
    ### Why it matters here — 1–3 sentences tying it to the current task/context.
    """
  end

  @doc """
  Compare two statements, surface common ground and tensions, and propose a synthesis
  or a clear scope boundary.
  """
  @spec question_synthesis(String.t(), String.t()) :: String.t()
  def question_synthesis(a, b) when is_binary(a) and is_binary(b) do
    """
    Instruction:
    Compare "#{a}" and "#{b}". Length: ~120–180 words.
    Use this structure:
    ### Common ground — 2–3 bullets.
    ### Tensions — 2–3 bullets (specific).
    ### Synthesis / Scope boundary — one compact paragraph or 2–3 bullets with when‑to‑use‑which.
    """
  end

  @doc """
  Make a concise, rigorous case for a statement with fixed micro‑sections.
  """
  @spec question_thesis(String.t()) :: String.t()
  def question_thesis(statement) when is_binary(statement) do
    """
    Instruction:
    Make a brief, rigorous case for "#{statement}". Length: ~100–160 words.
    Use this structure:
    ### Claim — one sentence.
    ### Reasoning — 3 bullets, each a distinct argument.
    ### Example — 2–3 sentences.
    """
  end

  @doc """
  Provide a concise, rigorous critique with fixed micro‑sections.
  """
  @spec question_antithesis(String.t()) :: String.t()
  def question_antithesis(statement) when is_binary(statement) do
    """
    Instruction:
    Critique "#{statement}" rigorously. Length: ~120–180 words.
    Use this structure:
    ### Steelman — the best case for the claim.
    ### Core objection — the key flaw or boundary.
    ### Support / Counterexample — 2–4 sentences.
    """
  end

  @doc """
  Suggest diverse, related concepts to explore next.
  """
  @spec question_related_ideas(String.t()) :: String.t()
  def question_related_ideas(title) when is_binary(title) do
    """
    Instruction:
    Start your answer with:
    ## Related ideas
    Suggest diverse, related concepts to explore next for "#{title}". Return 6–8 bullets; each bullet: Concept — one‑sentence rationale or contrast. Total ≤120 words.
    """
  end

  @doc """
  Explain a concept rigorously for an advanced learner with explicit structure.
  """
  @spec question_deepdive(String.t()) :: String.t()
  def question_deepdive(topic) when is_binary(topic) do
    """
    Instruction:
    Explain "#{topic}" rigorously for an advanced learner. Length: 2–4 compact paragraphs (~140–220 words).
    Use this structure:
    Paragraph 1: core definition and intuition.
    Paragraph 2: formal relationship/mechanics.
    Paragraph 3: Assumptions & Scope (explicit).
    Optional: Brief Caveats if they reduce misuse.
    """
  end
end
