defmodule Dialectic.LLM.VoiceTranscriber do
  @moduledoc """
  Transcribes audio to text using Gemini's inline audio understanding API.

  Sends base64-encoded audio directly to the Gemini REST API (generateContent)
  with an inline_data part, asking for a verbatim transcription of the speech.

  This bypasses ReqLLM since it doesn't support multimodal inline_data parts.
  We call the REST endpoint directly via Req.

  ## Usage

      case VoiceTranscriber.transcribe(base64_audio, "audio/webm") do
        {:ok, text} -> # use transcribed text
        {:error, reason} -> # handle error
      end
  """

  require Logger

  @transcription_model "gemini-3.1-flash-lite-preview"

  @base_url "https://generativelanguage.googleapis.com/v1beta/models"

  @transcription_prompt """
  Transcribe the speech in this audio clip verbatim. Return ONLY the exact words spoken,
  with no additional commentary, labels, timestamps, or formatting. If no speech is
  detected, return an empty string. Do not add quotation marks around the transcription.
  """

  @doc """
  Transcribes the given base64-encoded audio data to text.

  ## Parameters
    - `base64_audio` — base64-encoded audio bytes (e.g. from a browser MediaRecorder)
    - `mime_type` — the MIME type of the audio (e.g. "audio/webm", "audio/ogg", "audio/mp4")

  ## Returns
    - `{:ok, transcribed_text}` on success
    - `{:error, reason}` on failure
  """
  @spec transcribe(String.t(), String.t()) :: {:ok, String.t()} | {:error, term()}
  def transcribe(base64_audio, mime_type \\ "audio/webm") do
    with {:ok, api_key} <- fetch_api_key(),
         {:ok, response} <- call_gemini(api_key, base64_audio, mime_type),
         {:ok, text} <- extract_text(response) do
      {:ok, String.trim(text)}
    end
  end

  @doc """
  Returns the model used for voice transcription.
  """
  def model, do: @transcription_model

  # ── Private helpers ──────────────────────────────────────────────────

  defp fetch_api_key do
    case System.get_env("GOOGLE_API_KEY") do
      nil -> {:error, :missing_api_key}
      "" -> {:error, :missing_api_key}
      key -> {:ok, key}
    end
  end

  defp call_gemini(api_key, base64_audio, mime_type) do
    url = "#{@base_url}/#{@transcription_model}:generateContent"

    body = %{
      "contents" => [
        %{
          "parts" => [
            %{
              "text" => @transcription_prompt
            },
            %{
              "inline_data" => %{
                "mime_type" => normalize_mime_type(mime_type),
                "data" => base64_audio
              }
            }
          ]
        }
      ],
      "generationConfig" => %{
        "temperature" => 0.0,
        "maxOutputTokens" => 2048
      }
    }

    Logger.debug(fn ->
      audio_size_kb = Float.round(byte_size(base64_audio) * 0.75 / 1024, 1)

      "[VoiceTranscriber] Sending #{audio_size_kb}KB audio (#{mime_type}) to #{@transcription_model}"
    end)

    case Req.post(url,
           json: body,
           params: [key: api_key],
           headers: [{"content-type", "application/json"}],
           connect_options: [timeout: 30_000],
           receive_timeout: 60_000
         ) do
      {:ok, %Req.Response{status: 200, body: response_body}} ->
        {:ok, response_body}

      {:ok, %Req.Response{status: status, body: error_body}} ->
        error_message = extract_error_message(error_body)

        Logger.error(
          "[VoiceTranscriber] Gemini API error (HTTP #{status}): #{inspect(error_message)}"
        )

        {:error, {:api_error, status, error_message}}

      {:error, reason} ->
        Logger.error("[VoiceTranscriber] Request failed: #{inspect(reason)}")
        {:error, {:request_failed, reason}}
    end
  end

  defp extract_text(%{"candidates" => [%{"content" => %{"parts" => parts}} | _]}) do
    text =
      parts
      |> Enum.map(fn
        %{"text" => t} -> t
        _ -> ""
      end)
      |> Enum.join("")

    if text == "" do
      {:error, :empty_transcription}
    else
      {:ok, text}
    end
  end

  defp extract_text(%{"candidates" => []}) do
    {:error, :no_candidates}
  end

  defp extract_text(%{"error" => %{"message" => message}}) do
    {:error, {:api_error, message}}
  end

  defp extract_text(other) do
    Logger.warning("[VoiceTranscriber] Unexpected response shape: #{inspect(other)}")
    {:error, :unexpected_response}
  end

  defp extract_error_message(%{"error" => %{"message" => msg}}), do: msg
  defp extract_error_message(body) when is_map(body), do: inspect(body)
  defp extract_error_message(body) when is_binary(body), do: body
  defp extract_error_message(body), do: inspect(body)

  defp normalize_mime_type("audio/webm;codecs=opus"), do: "audio/webm"
  defp normalize_mime_type("audio/ogg;codecs=opus"), do: "audio/ogg"
  defp normalize_mime_type(mime) when is_binary(mime), do: mime
  defp normalize_mime_type(_), do: "audio/webm"
end
