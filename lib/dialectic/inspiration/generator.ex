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
    provider_mod = get_provider()

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

    case make_request(provider_mod, system_prompt, preferences_prompt) do
      {:ok, resp} ->
        text = extract_text(resp)

        case parse_response(text) do
          {:ok, questions} ->
            {:ok, questions}

          {:error, _} = err ->
            Logger.warning("Inspiration generator failed to parse response: #{inspect(resp)}")
            err
        end

      {:error, reason} ->
        Logger.error("Inspiration generator LLM error: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp parse_response(text) do
    text = to_string(text || "")

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

  defp make_request(provider_mod, system_prompt, user_prompt) do
    # Validate configuration early to surface clear messages
    case Dialectic.LLM.Provider.api_key(provider_mod) do
      {:ok, _api_key} ->
        # Use a faster model for inspiration generation, regardless of the app-wide provider model.
        # Gemini 2.5 Flash-Lite is optimized for low-latency, lightweight generations like this.
        model_spec =
          case provider_mod.id() do
            :google -> {:google, [model: "gemini-2.5-flash-lite"]}
            _ -> Dialectic.LLM.Provider.model_spec(provider_mod)
          end

        provider_options = provider_mod.provider_options()

        ctx =
          ReqLLM.Context.new([
            ReqLLM.Context.system(system_prompt),
            ReqLLM.Context.user(user_prompt)
          ])

        # Non-streaming: request the full response in one shot.
        #
        # IMPORTANT:
        # - ReqLLM non-streaming generation validates options strictly.
        # - Credentials should be provided via environment/config (e.g. GOOGLE_API_KEY / OPENAI_API_KEY)
        #   rather than passing per-request credential keys.
        # - `:finch_name` is not a supported option for ReqLLM generation calls.
        ReqLLM.generate_text(
          model_spec,
          ctx,
          provider_options: provider_options
        )

      {:error, _} = error ->
        error
    end
  end

  defp extract_text(%ReqLLM.Response{} = resp) do
    ReqLLM.Response.text(resp)
  end

  defp extract_text(text) when is_binary(text), do: text
  defp extract_text(other), do: to_string(other || "")

  defp get_provider do
    case System.get_env("LLM_PROVIDER") do
      "google" -> Dialectic.LLM.Providers.Google
      "gemini" -> Dialectic.LLM.Providers.Google
      _ -> Dialectic.LLM.Providers.OpenAI
    end
  end
end
