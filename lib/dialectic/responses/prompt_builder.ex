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
    Answer "#{user_request}" directly. Be clear and compact; use bullets only if they aid clarity.
    """
  end

  @doc """
  Paraphrase a selected passage and explain its relevance to the current topic.
  """
  @spec question_selection(String.t()) :: String.t()
  def question_selection(selection) when is_binary(selection) do
    """
    Instruction (apply to the selection below):
    #{selection}

    Instruction:
    Paraphrase the selection and explain its relevance to the current context. Be brief; use bullets only if they clarify key claims, assumptions, implications, or limitations.
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
    Compare "#{a}" and "#{b}": name common ground and key tensions; propose a synthesis or clear scope boundary. Keep it concise; use bullets only to highlight trade‑offs.
    """
  end

  @doc """
  Make a concise, rigorous case for a statement: claim, reasons, and one short example if useful.
  """
  @spec question_thesis(String.t()) :: String.t()
  def question_thesis(statement) when is_binary(statement) do
    """
    Instruction:
    Make a brief, rigorous case for "#{statement}": state the claim, give compact reasoning, and add one short example if useful.
    """
  end

  @doc """
  Provide a concise, rigorous critique: steelman the opposing view, state the core objection,
  and support it with compact reasoning and (optionally) a short counterexample.
  """
  @spec question_antithesis(String.t()) :: String.t()
  def question_antithesis(statement) when is_binary(statement) do
    """
    Instruction:
    Give a brief, rigorous critique of "#{statement}": steelman the opposing view, state the core objection, and support it with compact reasoning and, if helpful, a short counterexample.
    """
  end

  @doc """
  Suggest diverse, related concepts for follow-up exploration as a concise bullet list.
  Each bullet: concept — one-sentence rationale or contrast.
  """
  @spec question_related_ideas(String.t()) :: String.t()
  def question_related_ideas(title) when is_binary(title) do
    """
    Instruction:
    Suggest diverse, related concepts to explore next for "#{title}". Return a concise bullet list; each bullet: concept — one‑sentence rationale or contrast.
    """
  end

  @doc """
  Explain a topic rigorously for an advanced learner: name assumptions and scope; use 2–4
  compact paragraphs; add brief caveats only if they clarify.
  """
  @spec question_deepdive(String.t()) :: String.t()
  def question_deepdive(topic) when is_binary(topic) do
    """
    Instruction:
    Explain "#{topic}" rigorously for an advanced learner: note assumptions and scope. Use 2–4 compact paragraphs; add brief caveats only if they clarify.
    """
  end
end
