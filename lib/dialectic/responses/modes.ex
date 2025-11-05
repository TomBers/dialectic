defmodule Dialectic.Responses.Modes do
  @moduledoc """
  Centralized definition of response modes and their system prompts.

  Scope:
  - Provides a curated set of response modes the UI can expose (dropdown + cycle button).
  - Returns a single base style prompt plus mode-specific guidance.
  - Does not change model params; only prompt content varies by mode.

  Typical usage:

      # Build the full system prompt for a given mode (atom or string).
      system = Dialectic.Responses.Modes.system_prompt(:structured)

      # Or compose a ready-to-send prompt from a question and a mode.
      combined = Dialectic.Responses.Modes.compose(question, :creative)

      # Cycle the current mode for a “cycle” button.
      next_mode = Dialectic.Responses.Modes.cycle(:structured)

  Notes:
  - The default mode is :structured.
  - If an unrecognized mode is passed, functions fall back to the default.
  """

  @type mode_id :: :structured | :creative
  # The following modes are intentionally disabled for now, but kept for later:
  #   :balanced | :concise | :conversational | :deep_dive | :socratic

  @default_mode :structured

  @mode_order [
    :structured,
    :creative
    # :balanced,
    # :concise,
    # :conversational,
    # :deep_dive,
    # :socratic
  ]

  # Keep a concise, non-repetitive base style used everywhere.
  @base_style """
  You are teaching a curious beginner toward university-level mastery.
  - Form: Markdown. Begin with exactly one H2 title as the first line, using the task template’s title (Response, Selection, Synthesis, Thesis, Antithesis, Related ideas, Deepdive).
  - Brevity: short paragraphs (1–3 sentences). Use bullets only when they clarify. No tables.
  - Evidence: Prefer facts from the provided Context. Label anything else as "Background"; if unsure, mark Background — tentative or omit.
  - Process writing: when describing a procedure, use 3–7 numbered steps.
  - Checks: you may end with a 2–4-bullet Checklist or Summary if it adds value.
  - Clarification: if missing essential info, state what’s missing and ask one clarifying question at the end.
  - Guardrail: Don’t fabricate sources. If a necessary fact isn’t in Context and you can’t supply it as Background confidently, state the gap.
  """

  # Per-mode augmentations layered on top of the base style.
  @modes %{
    structured: %{
      id: :structured,
      label: "Structured",
      description: "Prioritize directness and structure; headings only when they add clarity.",
      prompt: """
      Mode: Structured
      - Prioritize directness and structure.
      - Headings only when they add clarity.
      - Avoid figurative analogies unless brief and precise.
      """
    },
    creative: %{
      id: :creative,
      label: "Creative/Exploratory",
      description:
        "Encourage contrasting lenses, vivid analogies, and clearly labeled speculation.",
      prompt: """
      Mode: Creative
      - Offer 2–3 contrasting lenses or what‑ifs.
      - Use vivid but accurate analogies; label any conjecture as Speculation.
      - Separate takes with mini‑subheadings (preferred) or bullets.
      """
    }
    # --- Unused modes kept for later (commented out) ---
    # ,balanced: %{
    #   id: :balanced,
    #   label: "Balanced",
    #   description: "General-purpose mode that balances brevity with structure for first-time learners.",
    #   prompt: """
    #   Mode: Balanced
    #   - Balance clarity, structure, and brevity.
    #   - Keep total length proportional to the task; do not pad.
    #   - Avoid canned section labels unless explicitly requested.
    #   """
    # }
    # ,concise: %{
    #   id: :concise,
    #   label: "Concise",
    #   description: "Crisp answers in as few words as possible without losing essentials.",
    #   prompt: """
    #   Mode: Concise
    #   - Be brief. Prefer 1–2 short paragraphs or 3–5 bullets.
    #   - Avoid headings unless explicitly requested.
    #   - State the core idea directly; avoid hedging and redundancy.
    #   """
    # }
    # ,conversational: %{
    #   id: :conversational,
    #   label: "Conversational",
    #   description: "Friendly, approachable tone; easy to skim in paragraphs.",
    #   prompt: """
    #   Mode: Conversational
    #   - Use a friendly, natural tone with light rhetorical questions.
    #   - Prefer plain paragraphs; bullets only for options/examples.
    #   - Keep jargon minimal and explain briefly if needed.
    #   """
    # }
    # ,deep_dive: %{
    #   id: :deep_dive,
    #   label: "Deep-dive",
    #   description: "More technical depth and nuance; assume a motivated learner.",
    #   prompt: """
    #   Mode: Deep-dive
    #   - Increase precision; name assumptions and note limitations.
    #   - Use compact formalism where it clarifies; define terms briefly.
    #   - Include brief caveats when helpful; avoid generic fixed labels.
    #   """
    # }
    # ,socratic: %{
    #   id: :socratic,
    #   label: "Socratic",
    #   description: "Lead with guiding questions, then explain; end with a follow-up.",
    #   prompt: """
    #   Mode: Socratic
    #   - Start with 2–4 short questions to probe the user's model.
    #   - Then provide a concise explanation addressing them.
    #   - End with one short follow-up question.
    #   """
    # }
  }

  @doc """
  Returns the canonical order of modes (used by cycling UIs).
  """
  @spec order() :: [mode_id()]
  def order, do: @mode_order

  @doc """
  Returns the default mode id.
  """
  @spec default() :: mode_id()
  def default, do: @default_mode

  @doc """
  Returns the base style applied to all modes before per-mode guidance.
  """
  @spec base_style() :: String.t()
  def base_style, do: @base_style

  @doc """
  Lists all modes as maps with keys:
  - :id (atom)
  - :label (string)
  - :description (string)
  - :prompt (string)
  """
  @spec list() :: [map()]
  def list do
    @mode_order
    |> Enum.map(&fetch(&1))
  end

  @doc """
  Fetch a mode by id (atom or string). Falls back to the default mode if not found.
  """
  @spec fetch(mode_id() | String.t()) :: map()
  def fetch(mode) when is_binary(mode) do
    mode
    |> normalize_id()
    |> fetch()
  end

  def fetch(mode) when is_atom(mode) do
    Map.get(@modes, mode, Map.fetch!(@modes, @default_mode))
  end

  @doc """
  True if the mode id is known.
  """
  @spec valid?(mode_id() | String.t()) :: boolean()
  def valid?(mode) do
    mode
    |> normalize_id()
    |> then(&Map.has_key?(@modes, &1))
  end

  @doc """
  Normalize external params to an internal atom id.
  Unknown values resolve to the default mode.
  """
  @spec normalize_id(mode_id() | String.t() | nil) :: mode_id()
  def normalize_id(nil), do: @default_mode

  def normalize_id(mode) when is_atom(mode) do
    if Map.has_key?(@modes, mode), do: mode, else: @default_mode
  end

  def normalize_id(mode) when is_binary(mode) do
    case String.downcase(mode) do
      "structured" -> :structured
      "creative" -> :creative
      # "balanced" -> :balanced
      # "concise" -> :concise
      # "conversational" -> :conversational
      # "deep-dive" -> :deep_dive
      # "deep_dive" -> :deep_dive
      # "deepdive" -> :deep_dive
      # "socratic" -> :socratic
      _ -> @default_mode
    end
  end

  @doc """
  Returns only the per-mode guidance prompt (without the base style).
  """
  @spec mode_prompt(mode_id() | String.t()) :: String.t()
  def mode_prompt(mode) do
    mode
    |> fetch()
    |> Map.fetch!(:prompt)
  end

  @doc """
  Returns the full system prompt for a given mode:
  base_style() <> 2 newlines <> mode_prompt(mode)
  """
  @spec system_prompt(mode_id() | String.t()) :: String.t()
  def system_prompt(mode) do
    base_style() <> "\n\n" <> mode_prompt(mode)
  end

  @doc """
  Convenience: compose a ready-to-send prompt by prefixing the system prompt to the question.
  """
  @spec compose(String.t(), mode_id() | String.t()) :: String.t()
  def compose(question, mode) when is_binary(question) do
    system_prompt(mode) <> "\n\n" <> question
  end

  @doc """
  Cycle to the next mode in the canonical order, wrapping at the end.
  Unknown modes return the default.
  """
  @spec cycle(mode_id() | String.t()) :: mode_id()
  def cycle(current) do
    current_id = normalize_id(current)

    case Enum.find_index(@mode_order, &(&1 == current_id)) do
      nil -> @default_mode
      idx -> Enum.at(@mode_order, rem(idx + 1, length(@mode_order)))
    end
  end

  @doc """
  Returns a presentational tuple list: [{id, label, description}], ordered for UI dropdowns.
  """
  @spec options() :: [{mode_id(), String.t(), String.t()}]
  def options do
    list()
    |> Enum.map(fn m -> {m.id, m.label, m.description} end)
  end
end
