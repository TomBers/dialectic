defmodule Dialectic.Responses.Modes do
  @moduledoc """
  Centralized definition of response “modes” and their system prompts.

  Scope:
  - Provides a curated set of response modes the UI can expose (dropdown + cycle button).
  - Returns a base style prompt plus mode-specific guidance.
  - Does not change model params; only prompt content varies by mode.
  - Intended for use by whatever layer assembles the final prompt before enqueueing.

  Typical usage:

      # Build the full system prompt for a given mode (atom or string).
      system = Dialectic.Responses.Modes.system_prompt(:balanced)

      # Or compose a ready-to-send prompt from a question and a mode.
      combined = Dialectic.Responses.Modes.compose(question, :concise)

      # Cycle the current mode for a “cycle” button.
      next_mode = Dialectic.Responses.Modes.cycle(:balanced)

  Notes:
  - The default mode is :balanced.
  - If an unrecognized mode is passed, functions fall back to the default.
  """

  @type mode_id ::
          :balanced
          | :concise
          | :structured
          | :conversational
          | :deep_dive
          | :socratic
          | :creative

  @default_mode :balanced

  @mode_order [
    :balanced,
    :concise,
    :structured,
    :conversational,
    :deep_dive,
    :socratic,
    :creative
  ]

  # The shared teaching style used everywhere unless a particular mode overrides specifics.
  @base_style """
  You are teaching a curious beginner toward university-level mastery.
  - Default to markdown with an H2 title (## …).
  - Aim for clarity and compactness; favor short paragraphs over lists unless lists add clarity.
  - If context is insufficient, say what’s missing and ask one clarifying question.
  - Prefer information from the provided Context; label other info as "Background".
  - Avoid tables.
  Do not impose canned section headings; follow the mode’s guidance and the question’s intent.
  """

  # Per-mode augmentations layered on top of the base style.
  @modes %{
    balanced: %{
      id: :balanced,
      label: "Balanced",
      description:
        "General-purpose mode that balances brevity with structure for first-time learners.",
      prompt: """
      Mode: Balanced
      - Balance clarity, structure, and brevity.
      - Keep total length proportional to the task; do not pad.
      - Avoid canned section labels (e.g., "Deep dive", "Nuances", "Next steps") unless explicitly requested.
      """
    },
    concise: %{
      id: :concise,
      label: "Concise",
      description: "Crisp answers in as few words as possible without losing essential content.",
      prompt: """
      Mode: Concise
      - Be brief. Prefer 1–2 short paragraphs or 3–5 bullets maximum.
      - Avoid headings unless explicitly requested.
      - Remove redundancy and hedging; state the core idea directly.
      - No closing summaries unless explicitly requested.
      - Never introduce canned section labels (e.g., "Deep dive", "Nuances", "Next steps").
      """
    },
    structured: %{
      id: :structured,
      label: "Structured (steps)",
      description:
        "Well-organized answers with headings and clear step-by-step lists where helpful.",
      prompt: """
      Mode: Structured
      - Use clear section headings and short subsections.
      - When describing processes, use numbered steps (3–7 steps typical).
      - Include a brief summary or checklist at the end when appropriate.
      """
    },
    conversational: %{
      id: :conversational,
      label: "Conversational",
      description: "Friendly, approachable tone; light on headings; easy to skim in paragraphs.",
      prompt: """
      Mode: Conversational
      - Use a friendly, natural tone with light use of rhetorical questions.
      - Avoid headings; use plain paragraphs (2–4 sentences each).
      - Use bullets only when listing options or examples.
      - Keep jargon to a minimum and explain it briefly if necessary.
      - Do not introduce canned section labels (e.g., "Deep dive", "Nuances", "Next steps").
      """
    },
    deep_dive: %{
      id: :deep_dive,
      label: "Deep-dive",
      description: "More technical depth and nuance; assume a motivated learner who wants rigor.",
      prompt: """
      Mode: Deep-dive
      - Increase technical precision and nuance (name core assumptions; note limitations).
      - Prefer compact formalism when it clarifies (define symbols or terms briefly).
      - If helpful, include a brief caveat sentence or 1–2 bullets; avoid fixed section labels.
      - Avoid tables and generic headings (e.g., "Deep dive", "Nuances", "Next steps").
      """
    },
    socratic: %{
      id: :socratic,
      label: "Socratic",
      description:
        "Lead with 2–4 guiding questions; progressively reveal; ask one follow-up at the end.",
      prompt: """
      Mode: Socratic
      - Begin with 2–4 short questions to probe the user's current model.
      - Then give a concise explanation addressing those questions.
      - End with one short follow-up question to continue the dialogue.
      - Keep sections compact; avoid heavy headings.
      - Do not introduce canned section labels (e.g., "Deep dive", "Nuances", "Next steps").
      """
    },
    creative: %{
      id: :creative,
      label: "Creative/Exploratory",
      description: "Encourage brainstorming, analogies, and contrasting takes; flag speculation.",
      prompt: """
      Mode: Creative/Exploratory
      - Offer 2–3 divergent lenses or ‘what-if’ variations.
      - Use vivid but accurate analogies; explicitly label speculation as such.
      - Prefer short subsections or bullets to separate distinct takes; avoid fixed headings.
      - No canned section labels (e.g., "Deep dive", "Nuances", "Next steps") unless explicitly requested.
      """
    }
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
      "balanced" -> :balanced
      "concise" -> :concise
      "structured" -> :structured
      "conversational" -> :conversational
      "deep-dive" -> :deep_dive
      "deep_dive" -> :deep_dive
      "deepdive" -> :deep_dive
      "socratic" -> :socratic
      "creative" -> :creative
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
