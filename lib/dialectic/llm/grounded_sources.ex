defmodule Dialectic.LLM.GroundedSources do
  @moduledoc false

  @sources_section ~r/^## Sources[ \t]*\n.*?(?=^##[ \t]|\z)/ims
  @max_support_length 220

  @spec merge_metadata([map()], map()) :: [map()]
  def merge_metadata(sources, metadata) when is_list(sources) and is_map(metadata) do
    sources = normalize_sources(sources)
    offset = next_grounding_index(sources)

    sources
    |> Kernel.++(metadata_sources(metadata, offset))
    |> normalize_sources()
    |> apply_supports(metadata_supports(metadata))
  end

  def merge_metadata(sources, _metadata) when is_list(sources), do: sources

  @spec reconcile_markdown(String.t(), [map()]) :: String.t()
  def reconcile_markdown(markdown, sources) when is_binary(markdown) and is_list(sources) do
    if Regex.match?(@sources_section, markdown) do
      replacement = render_sources(normalize_sources(sources))

      @sources_section
      |> Regex.replace(markdown, replacement)
      |> String.replace(~r/\n{3,}/, "\n\n")
      |> String.trim_trailing()
    else
      markdown
    end
  end

  defp metadata_sources(metadata, offset) do
    provider_meta = fetch(metadata, :provider_meta) || metadata
    google_meta = fetch(provider_meta, :google) || %{}

    case fetch(google_meta, :sources) do
      sources when is_list(sources) ->
        sources
        |> Enum.with_index(offset)
        |> Enum.map(fn {source, index} -> Map.put(source, :grounding_index, index) end)

      _other ->
        []
    end
  end

  defp metadata_supports(metadata) do
    provider_meta = fetch(metadata, :provider_meta) || metadata
    google_meta = fetch(provider_meta, :google) || %{}
    grounding_metadata = fetch(google_meta, :grounding_metadata) || %{}

    grounding_metadata
    |> fetch("groundingSupports")
    |> List.wrap()
    |> Enum.reduce(%{}, fn support, supports_by_index ->
      text = support |> fetch(:segment) |> fetch(:text) |> normalize_support()
      indices = fetch(support, "groundingChunkIndices") || []

      if text && is_list(indices) do
        Enum.reduce(indices, supports_by_index, fn
          index, acc when is_integer(index) and index >= 0 ->
            Map.update(acc, index, [text], &Enum.uniq(&1 ++ [text]))

          _index, acc ->
            acc
        end)
      else
        supports_by_index
      end
    end)
  end

  defp normalize_sources(sources) do
    {order, sources_by_url} =
      Enum.reduce(sources, {[], %{}}, fn source, {order, sources_by_url} ->
        case normalize_source(source) do
          nil ->
            {order, sources_by_url}

          item ->
            if Map.has_key?(sources_by_url, item.url) do
              existing = Map.fetch!(sources_by_url, item.url)
              {order, Map.put(sources_by_url, item.url, merge_source(existing, item))}
            else
              {order ++ [item.url], Map.put(sources_by_url, item.url, item)}
            end
        end
      end)

    Enum.map(order, &Map.fetch!(sources_by_url, &1))
  end

  defp normalize_source(source) when is_map(source) do
    url = fetch(source, :uri) || fetch(source, :url)

    if valid_http_url?(url) do
      uri = URI.parse(url)
      title = normalize_title(fetch(source, :title), uri.host)

      grounding_indices =
        [fetch(source, :grounding_index) | List.wrap(fetch(source, :grounding_indices))]
        |> Enum.filter(&(is_integer(&1) and &1 >= 0))
        |> Enum.uniq()

      %{
        title: title,
        url: url,
        grounding_indices: grounding_indices,
        supports: normalize_supports(fetch(source, :supports))
      }
    end
  end

  defp normalize_source(_source), do: nil

  defp merge_source(existing, incoming) do
    %{
      existing
      | grounding_indices: Enum.uniq(existing.grounding_indices ++ incoming.grounding_indices),
        supports: Enum.uniq(existing.supports ++ incoming.supports)
    }
  end

  defp apply_supports(sources, supports_by_index) do
    Enum.map(sources, fn source ->
      supports =
        source.grounding_indices
        |> Enum.flat_map(&Map.get(supports_by_index, &1, []))
        |> then(&Enum.uniq(source.supports ++ &1))

      %{source | supports: supports}
    end)
  end

  defp next_grounding_index(sources) do
    sources
    |> Enum.flat_map(& &1.grounding_indices)
    |> Enum.max(fn -> -1 end)
    |> Kernel.+(1)
  end

  defp valid_http_url?(url) when is_binary(url) do
    uri = URI.parse(url)

    uri.scheme in ["http", "https"] and is_binary(uri.host) and uri.host != "" and
      not Regex.match?(~r/\s/, url)
  end

  defp valid_http_url?(_url), do: false

  defp normalize_title(title, fallback) when is_binary(title) do
    case String.trim(title) do
      "" -> fallback || "Source"
      value -> value
    end
  end

  defp normalize_title(_title, fallback), do: fallback || "Source"

  defp normalize_supports(supports) do
    supports
    |> List.wrap()
    |> Enum.map(&normalize_support/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  defp normalize_support(text) when is_binary(text) do
    text =
      text
      |> String.replace(~r/\s+/, " ")
      |> String.trim()

    cond do
      text == "" -> nil
      String.length(text) <= @max_support_length -> text
      true -> String.slice(text, 0, @max_support_length - 1) <> "…"
    end
  end

  defp normalize_support(_text), do: nil

  defp render_sources([]), do: ""

  defp render_sources(sources) do
    entries =
      sources
      |> Enum.with_index(1)
      |> Enum.map_join("\n", fn {source, index} ->
        entry = "#{index}. [#{escape_link_text(source.title)}](<#{source.url}>)"

        case List.first(source.supports) do
          nil -> entry
          support -> entry <> "\n   - Supports: “#{support}”"
        end
      end)

    "## Sources\n\n#{entries}\n\n"
  end

  defp escape_link_text(text) do
    text
    |> String.replace("\\", "\\\\")
    |> String.replace("[", "\\[")
    |> String.replace("]", "\\]")
  end

  defp fetch(nil, _key), do: nil

  defp fetch(map, key) when is_map(map) and is_atom(key) do
    Map.get(map, key) || Map.get(map, Atom.to_string(key))
  end

  defp fetch(map, key) when is_map(map) and is_binary(key), do: Map.get(map, key)
  defp fetch(_value, _key), do: nil
end
