defmodule Dialectic.Translate do
  @moduledoc """
  Server-side translation using Google Cloud Translation API v2 via Req.

  Configuration:

      # config/runtime.exs (recommended)
      config :dialectic, Dialectic.Translate,
        api_key: System.get_env("GOOGLE_TRANSLATE_API_KEY"),
        timeout_ms: 20_000

  By default, the API key is resolved in this order:
  1) opts[:api_key] passed to translate/3
  2) Application config: `:dialectic, Dialectic.Translate, :api_key`
  3) ENV var: GOOGLE_TRANSLATE_API_KEY

  Basic usage:

      iex> Dialectic.Translate.translate("Hello world", "es")
      {:ok, %Dialectic.Translate.Result{text: "Hola Mundo", target_lang: "es"}}

      iex> Dialectic.Translate.translate!("Hello world", "fr")
      "Bonjour le monde"

      iex> Dialectic.Translate.translate_many(["One", "Two"], "de")
      {:ok, [%{text: "Eins"}, %{text: "Zwei"}]}

  Notes:
  - This uses the v2 REST API: https://translation.googleapis.com/language/translate/v2
  - `target` should be an ISO 639-1 or BCP-47 code (e.g., "es", "pt-BR", "en").
  - If `source` is omitted, Google will auto-detect the source language.
  - The API returns HTML-escaped `translatedText`. We request `format: "text"`
    but you may still see HTML entities depending on content.
  """

  require Logger

  @endpoint "https://translation.googleapis.com/language/translate/v2"
  @default_timeout_ms 20_000
  @default_connect_timeout_ms 5_000

  defmodule Result do
    @moduledoc "Normalized single-translation result."
    defstruct [:text, :target_lang, :detected_source_lang, :raw]
  end

  @type lang_code :: String.t()
  @type error_reason ::
          :missing_api_key
          | :unavailable
          | :timeout
          | :decode_error
          | {:http_error, non_neg_integer()}
          | {:google_error, term()}
          | :empty

  @type translate_opts :: [
          {:api_key, String.t()},
          {:timeout, pos_integer()},
          {:connect_timeout, pos_integer()},
          {:source, lang_code() | nil},
          {:format, :text | :html}
        ]

  @doc """
  Translate a single `text` string into the target language `target`.

  Options:
  - `:source` - source language code (optional, defaults to auto-detect)
  - `:format` - `:text` (default) or `:html`
  - `:api_key` - override configured API key
  - `:timeout` / `:connect_timeout` - request timeouts in ms

  Returns `{:ok, %Result{}}` or `{:error, reason}`.
  """
  @spec translate(String.t(), lang_code(), translate_opts()) ::
          {:ok, %Result{}} | {:error, error_reason()}
  def translate(text, target, opts \\ []) when is_binary(text) and is_binary(target) do
    case translate_many([text], target, opts) do
      {:ok, [%{text: translated, detected_source_lang: detected} | _]} ->
        {:ok,
         %Result{
           text: translated,
           target_lang: normalize_target_passthrough(target),
           detected_source_lang: detected,
           raw: %{list: true}
         }}

      {:ok, []} ->
        {:error, :empty}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Same as `translate/3`, but returns the translated text or raises.
  """
  @spec translate!(String.t(), lang_code(), translate_opts()) :: String.t()
  def translate!(text, target, opts \\ []) do
    case translate(text, target, opts) do
      {:ok, %Result{text: translated}} ->
        translated

      {:error, reason} ->
        raise "Translation failed: #{inspect(reason)}"
    end
  end

  @doc """
  Translate a list of texts in a single call.

  Returns:
  - `{:ok, list}` where list is one entry per input (in order), each a map:
      %{
        text: "Translated text",
        detected_source_lang: "en" | nil,
        raw: map()
      }
  - or `{:error, reason}`
  """
  @spec translate_many([String.t()], lang_code(), translate_opts()) ::
          {:ok, [map()]} | {:error, error_reason()}
  def translate_many(texts, target, opts \\ []) when is_list(texts) and is_binary(target) do
    texts = Enum.map(texts, &to_string/1)

    with {:ok, key} <- resolve_api_key(opts),
         {:ok, payload} <- build_payload(texts, target, opts) do
      do_request(key, payload, opts)
    end
  end

  @doc """
  Same as `translate_many/3` but raises on error and returns the list of translated texts.
  """
  @spec translate_many!([String.t()], lang_code(), translate_opts()) :: [String.t()]
  def translate_many!(texts, target, opts \\ []) do
    case translate_many(texts, target, opts) do
      {:ok, results} ->
        Enum.map(results, & &1.text)

      {:error, reason} ->
        raise "Translation failed: #{inspect(reason)}"
    end
  end

  # -- Internal helpers

  defp resolve_api_key(opts) do
    key =
      Keyword.get(opts, :api_key) ||
        Application.get_env(:dialectic, __MODULE__, [])
        |> Keyword.get(:api_key) ||
        System.get_env("GOOGLE_TRANSLATE_API_KEY")

    if is_binary(key) and byte_size(key) > 0 do
      {:ok, key}
    else
      {:error, :missing_api_key}
    end
  end

  defp config_timeout do
    Application.get_env(:dialectic, __MODULE__, [])
    |> Keyword.get(:timeout_ms, @default_timeout_ms)
  end

  defp build_payload(texts, target, opts) do
    # Google supports ISO 639-1 and BCP-47 (e.g., "pt-BR"). We pass through as provided.
    target = normalize_target_passthrough(target)
    source = opts |> Keyword.get(:source) |> normalize_source_passthrough()
    format = opts |> Keyword.get(:format, :text) |> to_string()

    payload =
      %{
        "q" => texts,
        "target" => target,
        "format" => format
      }
      |> maybe_put_source(source)

    {:ok, payload}
  end

  defp maybe_put_source(payload, nil), do: payload
  defp maybe_put_source(payload, ""), do: payload
  defp maybe_put_source(payload, source), do: Map.put(payload, "source", source)

  defp do_request(key, payload, opts) do
    timeout = Keyword.get(opts, :timeout, config_timeout())
    connect_timeout = Keyword.get(opts, :connect_timeout, @default_connect_timeout_ms)

    req =
      Req.new(
        base_url: @endpoint,
        connect_options: [timeout: connect_timeout],
        receive_timeout: timeout,
        params: [key: key],
        headers: [{"content-type", "application/json"}]
      )

    case Req.post(req, json: payload) do
      {:ok, %{status: status, body: body}} when status in 200..299 ->
        parse_ok_response(body)

      {:ok, %{status: status, body: body}} ->
        parse_error_response(status, body)

      {:error, %Mint.TransportError{reason: :timeout}} ->
        {:error, :timeout}

      {:error, %Req.TransportError{reason: :timeout}} ->
        {:error, :timeout}

      {:error, other} ->
        Logger.debug("Google Translate error: #{inspect(other)}")
        {:error, :unavailable}
    end
  end

  defp parse_ok_response(body) when is_map(body) do
    case body do
      %{"data" => %{"translations" => translations}} when is_list(translations) ->
        {:ok, normalize_translations(translations)}

      %{data: %{translations: translations}} when is_list(translations) ->
        {:ok, normalize_translations(translations)}

      _ ->
        {:error, :decode_error}
    end
  end

  defp parse_ok_response(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, decoded} -> parse_ok_response(decoded)
      _ -> {:error, :decode_error}
    end
  end

  defp parse_error_response(status, body) do
    case decode_error_body(body) do
      {:ok, %{"error" => %{"message" => message}}} ->
        {:error, {:google_error, %{status: status, message: message}}}

      {:ok, %{error: %{message: message}}} ->
        {:error, {:google_error, %{status: status, message: message}}}

      _ ->
        {:error, {:http_error, status}}
    end
  end

  defp decode_error_body(body) when is_map(body), do: {:ok, body}

  defp decode_error_body(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, decoded} -> {:ok, decoded}
      _ -> :error
    end
  end

  defp normalize_translations(list) do
    Enum.map(list, fn t ->
      %{
        text: t["translatedText"] || t[:translatedText],
        detected_source_lang: t["detectedSourceLanguage"] || t[:detectedSourceLanguage],
        raw: t
      }
    end)
  end

  # Pass-through normalizers (trim + ensure sane casing when useful)

  defp normalize_target_passthrough(code) when is_binary(code) do
    code
    |> String.trim()
    |> normalize_common_casing()
  end

  defp normalize_source_passthrough(nil), do: nil

  defp normalize_source_passthrough(code) when is_binary(code) do
    code
    |> String.trim()
    |> normalize_common_casing()
  end

  defp normalize_common_casing(code) do
    # Keep BCP-47 style casing (e.g., pt-BR) normalized
    # - language lower-case; region upper-case if present
    case String.split(code, "-", parts: 2) do
      [lang, region] ->
        String.downcase(lang) <> "-" <> String.upcase(region)

      [lang] ->
        String.downcase(lang)

      _ ->
        code
    end
  end
end
