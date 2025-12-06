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
    You are a creative muse.
    Generate 5 thought-provoking questions for exploration based on the user's preferences.

    Rules:
    1. The output must be a valid JSON array of strings.
    2. Do not include markdown formatting (like ```json).
    3. Do not include any explanation or other text.
    4. Each question should be distinct and open-ended.
    """

    case make_request(provider_mod, system_prompt, preferences_prompt) do
      {:ok, text} ->
        case parse_response(text) do
          {:ok, questions} ->
            {:ok, questions}

          {:error, _} = err ->
            Logger.warning("Inspiration generator failed to parse response: #{text}")
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

  defp make_request(provider_mod, system_prompt, user_prompt) do
    case Dialectic.LLM.Provider.api_key(provider_mod) do
      {:ok, api_key} ->
        model_spec = Dialectic.LLM.Provider.model_spec(provider_mod)
        {_, receive_timeout} = Dialectic.LLM.Provider.timeouts(provider_mod)
        finch_name = Dialectic.LLM.Provider.finch_name(provider_mod)
        provider_options = provider_mod.provider_options()

        ctx =
          ReqLLM.Context.new([
            ReqLLM.Context.system(system_prompt),
            ReqLLM.Context.user(user_prompt)
          ])

        case ReqLLM.stream_text(
               model_spec,
               ctx,
               api_key: api_key,
               finch_name: finch_name,
               provider_options: provider_options,
               receive_timeout: receive_timeout
             ) do
          {:ok, stream_resp} ->
            text =
              stream_resp
              |> ReqLLM.StreamResponse.tokens()
              |> Enum.reduce("", fn token, acc ->
                chunk =
                  case token do
                    t when is_binary(t) -> t
                    t when is_list(t) -> IO.iodata_to_binary(t)
                    t -> to_string(t)
                  end

                acc <> chunk
              end)

            {:ok, text}

          {:error, _} = error ->
            error
        end

      {:error, _} = error ->
        error
    end
  end

  defp get_provider do
    case System.get_env("LLM_PROVIDER") do
      "google" -> Dialectic.LLM.Providers.Google
      "gemini" -> Dialectic.LLM.Providers.Google
      _ -> Dialectic.LLM.Providers.OpenAI
    end
  end
end
