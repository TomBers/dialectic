defmodule Dialectic.Inspiration.Generator do
  @moduledoc """
  Generates inspiration questions using an LLM based on user preferences.
  """
  require Logger

  @doc """
  Generates a list of questions based on the provided prompt configuration.
  Returns `{:ok, [question_strings]}` or `{:error, reason}`.
  """
  def generate_questions(preferences_prompt) do
    system_prompt = """
    You are a creative muse. Your goal is to spark curiosity and a desire to explore.
    Generate exactly 5 distinct, open-ended questions based on the user's preferences.

    Behavioral Rules:
    1. Question Shape:
       - Open-ended only. Explicitly forbid yes/no or one-word-answer questions.
       - Each question must invite elaboration and allow multiple valid perspectives.
       - Questions should be accessible and intriguing, even at higher depth/complexity.

    2. Variety:
       - The 5 questions must be meaningfully different in framing and angle.
       - Avoid minor rephrasings of the same underlying concept.

    Output Rules:
    1. The output must be a valid JSON array of strings.
    2. Do not include markdown formatting (like ```json).
    3. Do not include any explanation or other text.
    """

    # Use a faster model for inspiration generation
    opts = [
      system_prompt: system_prompt,
      model: "gemini-2.5-flash-lite"
    ]

    case Dialectic.LLM.Generator.generate(preferences_prompt, opts) do
      {:ok, text} ->
        case parse_response(text) do
          {:ok, questions} ->
            {:ok, questions}

          {:error, _} = err ->
            Logger.warning("Inspiration generator failed to parse response: #{inspect(text)}")
            err
        end

      {:error, reason} ->
        Logger.error("Inspiration generator LLM error: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp parse_response(text) do
    # Cleanup markdown code blocks if present
    clean_text =
      text
      |> String.replace(~r/^```json\s*/i, "")
      |> String.replace(~r/^```\s*/i, "")
      |> String.replace(~r/\s*```$/i, "")
      |> String.trim()

    case Jason.decode(clean_text) do
      {:ok, list} when is_list(list) ->
        # Filter for strings only and limit to reasonable length
        questions =
          list
          |> Enum.filter(&is_binary/1)
          |> Enum.map(&String.trim/1)
          |> Enum.reject(&(&1 == ""))
          |> Enum.take(5)

        {:ok, questions}

      _ ->
        {:error, :invalid_json}
    end
  end
end
