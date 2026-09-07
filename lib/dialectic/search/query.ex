defmodule Dialectic.Search.Query do
  @ignored_words ~w(a an the of in on to for and about)

  def terms(query) do
    words =
      query
      |> String.downcase()
      |> String.replace(~r/^do(?:es)?\s+(.+?)\s+exist[?.!]*$/u, "\\1")
      |> String.replace(
        ~r/^(?:(?:what|who|where|when|why|how)\s+(?:is|are|was|were|do|does|did|can|could|should|would)|(?:is|are|was|were|do|does|did|can|could|should|would))\s+/u,
        ""
      )
      |> String.trim_trailing("?")
      |> String.split(~r/\s+/u, trim: true)
      |> Enum.uniq()

    case Enum.reject(words, &(&1 in @ignored_words)) do
      [] -> words
      meaningful_words -> meaningful_words
    end
  end

  def matches?(text, terms) do
    text = String.downcase(text)
    terms != [] && Enum.all?(terms, &term_matches?(text, &1))
  end

  def short_term_pattern(term),
    do: "(^|[^[:alnum:]_])" <> Regex.escape(term) <> "([^[:alnum:]_]|$)"

  defp term_matches?(text, term) do
    if String.length(term) < 3 do
      Regex.match?(Regex.compile!(short_term_pattern(term), "iu"), text)
    else
      String.contains?(text, term)
    end
  end
end
