defmodule Dialectic.Graph.References do
  @moduledoc """
  Extracts references from an entire graph (literature-review style).

  Types detected (aiming to be inclusive rather than conservative):
    - URLs (http/https)
    - DOIs (10.xxxx/… and doi.org links)
    - arXiv identifiers (arXiv:YYMM.NNNNN with optional version, legacy cat/NNNNNNN, and arxiv.org links)
    - ISBN (10/13; permissive match, normalized by removing separators)
    - Bracketed numeric citations (e.g., “[1]”, “[1, 3–5]”)

  Returns consolidated references with:
    - type: :url | :doi | :arxiv | :isbn | :citation
    - label: human-friendly label
    - value: normalized value (unique key basis)
    - link: optional outbound URL (openable in new tab)
    - nodes: list of node IDs where this reference appears
    - count: total occurrences across graph
  """

  @type ref_type :: :url | :doi | :arxiv | :isbn | :citation
  @type ref :: %{
          type: ref_type(),
          label: String.t(),
          value: String.t(),
          link: String.t() | nil,
          nodes: [String.t()],
          count: non_neg_integer()
        }

  @trailing_punct ~r/[)\]\}\.,;:]+$/u
  @structured_conf_threshold 0.5

  @doc """
  Extracts and consolidates references from the entire digraph.

  Returns a list of references sorted by:
    1) type (doi, arxiv, url, isbn, citation)
    2) descending count
    3) label
  """
  @spec extract(:digraph.graph()) :: [ref()]
  def extract(graph) do
    graph
    |> enum_vertices()
    |> Enum.reduce(%{}, fn {id, content}, acc ->
      acc
      |> collect_urls(id, content)
      |> collect_dois(id, content)
      |> collect_arxiv(id, content)
      |> collect_isbn(id, content)
      |> collect_citations(id, content)
    end)
    |> Map.values()
    |> Enum.map(&finalize_ref/1)
    |> Enum.sort_by(fn r -> {type_rank(r.type), -r.count, r.label} end)
  end

  @doc """
  Extract references and return a map grouped by type.
  """
  @spec extract_by_type(:digraph.graph()) :: %{optional(ref_type()) => [ref()]}
  def extract_by_type(graph) do
    extract(graph)
    |> Enum.group_by(& &1.type)
  end

  @doc """
  The supported reference types in preferred display order.
  """
  @spec ref_types() :: [ref_type()]
  def ref_types, do: [:doi, :arxiv, :url, :isbn, :citation]

  # ───────────────────────────────────────────────────────────────────────────
  # Core collection helpers
  # ───────────────────────────────────────────────────────────────────────────

  defp enum_vertices(graph) do
    :digraph.vertices(graph)
    |> Enum.map(fn v ->
      case :digraph.vertex(graph, v) do
        {^v, %{id: id, content: content}} -> {to_string(id), to_string(content || "")}
        _ -> {to_string(v), ""}
      end
    end)
  end

  defp collect_urls(acc, node_id, content) do
    raw_urls =
      []
      |> Kernel.++(scan_href_urls(content))
      |> Kernel.++(scan_text_urls(content))

    acc1 =
      Enum.reduce(raw_urls, acc, fn url, a ->
        norm = normalize_url(url)

        key =
          {:url, String.downcase(norm)}

        merge_ref(a, key, %{
          type: :url,
          label: norm,
          value: norm,
          link: norm,
          nodes: MapSet.new([node_id]),
          count: 1
        })
      end)

    # Additionally, harvest structured references from ReferencesJSON if present
    acc2 =
      case Regex.run(~r/ReferencesJSON:\s*(.+)\s*$/mi, content) do
        [_, raw_json] ->
          json = normalize_curly_quotes(String.trim(raw_json))

          case Jason.decode(json) do
            {:ok, list} when is_list(list) ->
              Enum.reduce(list, acc1, fn ref, a ->
                if is_map(ref) do
                  conf =
                    case ref["confidence"] do
                      c when is_float(c) or is_integer(c) -> c * 1.0
                      _ -> 0.0
                    end

                  if conf >= @structured_conf_threshold do
                    type = ref["type"]

                    {key, label, value, link} =
                      case type do
                        "doi" ->
                          id = (ref["id"] || "") |> to_string()
                          norm = String.downcase(String.trim(id))
                          link = "https://doi.org/" <> id
                          {{:doi, norm}, "doi:" <> id, id, link}

                        "arxiv" ->
                          id = (ref["id"] || "") |> to_string()
                          norm = String.downcase(String.trim(id))
                          link = "https://arxiv.org/abs/" <> id
                          {{:arxiv, norm}, "arXiv:" <> id, id, link}

                        "isbn" ->
                          id = (ref["id"] || "") |> to_string()
                          norm = String.downcase(String.trim(id))
                          {{:isbn, norm}, "ISBN " <> id, id, nil}

                        "url" ->
                          url = (ref["url"] || "") |> to_string() |> normalize_url()
                          norm = String.downcase(url)
                          {{:url, norm}, url, url, url}

                        _ ->
                          # Fallback: treat as URL if possible
                          url = (ref["url"] || "") |> to_string() |> normalize_url()
                          norm = if url == "", do: (ref["id"] || "") |> to_string(), else: url

                          {{:url, String.downcase(norm)}, norm, norm,
                           if(url == "", do: nil, else: url)}
                      end

                    merge_ref(a, key, %{
                      type:
                        case key do
                          {:doi, _} -> :doi
                          {:arxiv, _} -> :arxiv
                          {:isbn, _} -> :isbn
                          {:url, _} -> :url
                          _ -> :url
                        end,
                      label:
                        (fn ->
                           t = (ref["title"] || "") |> to_string() |> String.trim()
                           if t != "", do: t, else: label
                         end).(),
                      value: value,
                      link: link,
                      nodes: MapSet.new([node_id]),
                      count: 1,
                      title: (ref["title"] || "") |> to_string(),
                      authors:
                        case ref["authors"] do
                          l when is_list(l) -> l
                          _ -> []
                        end,
                      year:
                        case ref["year"] do
                          y when is_integer(y) -> y
                          y when is_float(y) -> trunc(y)
                          _ -> nil
                        end,
                      venue: (ref["venue"] || "") |> to_string(),
                      confidence: conf
                    })
                  else
                    a
                  end
                else
                  a
                end
              end)

            _ ->
              acc1
          end

        _ ->
          acc1
      end

    acc2
  end

  defp collect_dois(acc, node_id, content) do
    # Gather DOIs appearing as raw 10.xxxx/... or inside doi.org links
    dois =
      []
      |> Kernel.++(scan_doi_org_urls(content))
      |> Kernel.++(scan_raw_dois(content))

    Enum.reduce(dois, acc, fn doi, a ->
      norm = normalize_doi(doi)
      link = "https://doi.org/#{norm}"

      key = {:doi, String.downcase(norm)}

      merge_ref(a, key, %{
        type: :doi,
        label: "doi:#{norm}",
        value: norm,
        link: link,
        nodes: MapSet.new([node_id]),
        count: 1
      })
    end)
  end

  defp collect_arxiv(acc, node_id, content) do
    ids =
      []
      |> Kernel.++(scan_arxiv_tags(content))
      |> Kernel.++(scan_arxiv_urls(content))
      |> Kernel.++(scan_arxiv_legacy_ids(content))

    Enum.reduce(ids, acc, fn id, a ->
      norm = normalize_arxiv_id(id)
      link = "https://arxiv.org/abs/#{norm}"

      key = {:arxiv, String.downcase(norm)}

      merge_ref(a, key, %{
        type: :arxiv,
        label: "arXiv:#{norm}",
        value: norm,
        link: link,
        nodes: MapSet.new([node_id]),
        count: 1
      })
    end)
  end

  defp collect_isbn(acc, node_id, content) do
    # Permissive match, then normalize (remove separators); we keep both 10/13 lengths.
    matches =
      scan_isbn(content)
      |> Enum.map(&normalize_isbn/1)
      |> Enum.uniq()

    Enum.reduce(matches, acc, fn isbn, a ->
      key = {:isbn, String.downcase(isbn)}

      merge_ref(a, key, %{
        type: :isbn,
        label: "ISBN #{pretty_isbn(isbn)}",
        value: isbn,
        link: isbn_link(isbn),
        nodes: MapSet.new([node_id]),
        count: 1
      })
    end)
  end

  defp collect_citations(acc, node_id, content) do
    # Expand “[1]”, “[2–4]”, “[3,5,7]” etc. into individual numeric citations
    citations = scan_citations(content)

    Enum.reduce(citations, acc, fn n, a ->
      key = {:citation, Integer.to_string(n)}

      merge_ref(a, key, %{
        type: :citation,
        label: "[#{n}]",
        value: Integer.to_string(n),
        link: nil,
        nodes: MapSet.new([node_id]),
        count: 1
      })
    end)
  end

  # Merge or insert reference
  defp merge_ref(acc, key, ref) do
    case Map.get(acc, key) do
      nil ->
        Map.put(acc, key, ref)

      %{nodes: nodes, count: cnt} = existing ->
        merged_nodes = MapSet.put(nodes, hd(MapSet.to_list(ref.nodes)))

        merged_link =
          cond do
            is_binary(existing[:link]) and existing[:link] != "" -> existing[:link]
            true -> ref[:link]
          end

        merged_title =
          if (existing[:title] || "") |> to_string() != "" do
            existing[:title]
          else
            ref[:title]
          end

        merged_authors =
          cond do
            is_list(existing[:authors]) and length(existing[:authors]) > 0 -> existing[:authors]
            is_list(ref[:authors]) -> ref[:authors]
            true -> []
          end

        merged_year =
          cond do
            is_integer(existing[:year]) -> existing[:year]
            is_integer(ref[:year]) -> ref[:year]
            true -> nil
          end

        merged_venue =
          cond do
            (existing[:venue] || "") != "" -> existing[:venue]
            true -> ref[:venue]
          end

        merged_confidence =
          case {existing[:confidence], ref[:confidence]} do
            {a, b} when is_number(a) and is_number(b) -> max(a, b)
            {a, _} when is_number(a) -> a
            {_, b} when is_number(b) -> b
            _ -> nil
          end

        Map.put(
          acc,
          key,
          Map.merge(existing, %{
            nodes: merged_nodes,
            count: cnt + 1,
            link: merged_link,
            title: merged_title,
            authors: merged_authors,
            year: merged_year,
            venue: merged_venue,
            confidence: merged_confidence
          })
        )
    end
  end

  defp finalize_ref(%{nodes: %MapSet{} = nodes} = r),
    do: %{r | nodes: nodes |> MapSet.to_list() |> Enum.sort()}

  defp finalize_ref(r), do: r

  # ───────────────────────────────────────────────────────────────────────────
  # URL detection
  # ───────────────────────────────────────────────────────────────────────────

  defp scan_href_urls(content) do
    # Extract href="..." or href='...'
    hrefs =
      Regex.scan(~r/href\s*=\s*["']([^"']+)["']/i, content)
      |> Enum.map(fn [_, href] -> href end)

    # Also extract Markdown links: [text](url)
    md_urls =
      Regex.scan(~r/\[[^\]]*\]\((https?:\/\/[^\s\)]+|www\.[^\s\)]+)\)/i, content)
      |> Enum.map(fn [_, url] -> url end)

    (hrefs ++ md_urls)
    |> Enum.map(&normalize_url/1)
    |> Enum.uniq()
  end

  defp scan_text_urls(content) do
    # Match plain text URLs. Avoid trailing punctuation.
    # Include within HTML text by removing tags copy (but we still scan raw).

    # http(s) URLs in raw content
    raw_http =
      Regex.scan(~r/\bhttps?:\/\/[^\s<>"'\)\]\}]+/i, content)
      |> Enum.map(fn [m] -> m end)

    # bare www.* URLs in raw content
    raw_www =
      Regex.scan(~r/\bwww\.[^\s<>"'\)\]\}]+/i, content)
      |> Enum.map(fn [m] -> m end)

    # http(s) URLs after stripping HTML
    stripped_http =
      content
      |> strip_html()
      |> then(fn s -> Regex.scan(~r/\bhttps?:\/\/[^\s<>"'\)\]\}]+/i, s) end)
      |> Enum.map(fn [m] -> m end)

    # bare www.* URLs after stripping HTML
    stripped_www =
      content
      |> strip_html()
      |> then(fn s -> Regex.scan(~r/\bwww\.[^\s<>"'\)\]\}]+/i, s) end)
      |> Enum.map(fn [m] -> m end)

    (raw_http ++ raw_www ++ stripped_http ++ stripped_www)
    |> Enum.map(&normalize_url/1)
    |> Enum.uniq()
  end

  defp normalize_url(url) do
    url =
      url
      |> String.trim()
      |> String.replace(@trailing_punct, "")

    # If it looks like a bare domain starting with www., prepend https://
    if String.match?(url, ~r/^(?i)www\./) do
      "https://" <> url
    else
      url
    end
  end

  # ───────────────────────────────────────────────────────────────────────────
  # DOI detection
  # ───────────────────────────────────────────────────────────────────────────

  # doi.org URLs -> extract the DOI path
  defp scan_doi_org_urls(content) do
    # e.g., https://doi.org/10.1000/xyz123
    Regex.scan(~r/\bhttps?:\/\/doi\.org\/(10\.\d{4,9}\/[^\s<>"'\)\]\}]+)\b/i, strip_html(content))
    |> Enum.map(fn [_, doi] -> doi end)
  end

  defp scan_raw_dois(content) do
    # Raw DOI patterns possibly prefixed with "doi:" or "DOI "
    # Based on https://www.crossref.org/blog/dois-and-matching-regular-expressions/
    in_text =
      Regex.scan(~r/\b(10\.\d{4,9}\/[^\s"<>]+)\b/i, strip_html(content))
      |> Enum.map(fn [m, _] -> m end)

    with_prefix =
      Regex.scan(~r/\bdoi[:\s]\s*(10\.\d{4,9}\/[^\s"<>]+)\b/i, content)
      |> Enum.map(fn [_, d] -> d end)

    Enum.uniq(in_text ++ with_prefix)
  end

  defp normalize_doi(doi) do
    doi
    |> String.trim()
    |> String.trim_trailing("/")
    |> strip_trailing_punct()
  end

  # ───────────────────────────────────────────────────────────────────────────
  # arXiv detection
  # ───────────────────────────────────────────────────────────────────────────

  defp scan_arxiv_tags(content) do
    # arXiv:YYMM.NNNNN[vN] and arXiv:hep-th/9901001
    Regex.scan(~r/\barXiv:\s*([A-Za-z\-\.]+\/\d{7}|\d{4}\.\d{4,5})(?:v\d+)?\b/i, content)
    |> Enum.map(fn [_, id] -> id end)
  end

  defp scan_arxiv_urls(content) do
    # https://arxiv.org/abs/<id> or /pdf/<id>.pdf
    Regex.scan(
      ~r/\bhttps?:\/\/arxiv\.org\/(?:abs|pdf)\/([A-Za-z\-\.]+\/\d{7}|\d{4}\.\d{4,5})(?:\.pdf)?\b/i,
      strip_html(content)
    )
    |> Enum.map(fn [_, id] -> id end)
  end

  defp scan_arxiv_legacy_ids(content) do
    # Legacy IDs like hep-th/9901001 possibly not prefixed; be permissive but avoid false positives by requiring a slash with 7 digits.
    Regex.scan(~r/\b([A-Za-z\-\.]+\/\d{7})\b/, strip_html(content))
    |> Enum.map(fn [_, id] -> id end)
  end

  defp normalize_arxiv_id(id) do
    id
    |> String.trim()
    |> String.replace(~r/^(?:arXiv:)/i, "")
    |> String.replace(~r/\.pdf$/i, "")
  end

  # ───────────────────────────────────────────────────────────────────────────
  # ISBN detection
  # ───────────────────────────────────────────────────────────────────────────

  defp scan_isbn(content) do
    # Capture broader ISBN-like tokens with optional "ISBN"/"ISBN-10"/"ISBN-13" prefix
    # Then normalize by removing hyphens/spaces and keep 10/13 lengths.
    raw =
      Regex.scan(
        ~r/\bISBN(?:-1[03])?:?\s*([0-9Xx][0-9Xx\s-]{7,19}[0-9Xx])\b/,
        content
      )
      |> Enum.map(fn [_, body] -> body end)

    # Also try to grab standalone sequences that look like ISBNs (fallback)
    fallback =
      Regex.scan(~r/\b([0-9Xx][0-9Xx\s-]{8,}[0-9Xx])\b/, strip_html(content))
      |> Enum.map(fn [_, body] -> body end)

    Enum.uniq(raw ++ fallback)
  end

  defp normalize_isbn(token) do
    token
    |> String.replace(~r/[\s\-\x{2010}\x{2011}\x{2012}\x{2013}\x{2014}\x{2212}]/u, "")
    |> String.upcase()
    |> then(fn s ->
      cond do
        String.length(s) == 10 -> s
        String.length(s) == 13 -> s
        true -> s
      end
    end)
  end

  defp pretty_isbn(isbn) do
    # Minimal prettifier: show as ISBN-10/ISBN-13 if length matches, otherwise raw
    case String.length(isbn) do
      10 -> "ISBN-10 #{isbn}"
      13 -> "ISBN-13 #{isbn}"
      _ -> isbn
    end
  end

  defp isbn_link(isbn) do
    # Provide a generic lookup link (optional)
    case String.length(isbn) do
      10 -> "https://isbnsearch.org/isbn/#{isbn}"
      13 -> "https://isbnsearch.org/isbn/#{isbn}"
      _ -> nil
    end
  end

  # ───────────────────────────────────────────────────────────────────────────
  # Citation detection
  # ───────────────────────────────────────────────────────────────────────────

  defp scan_citations(content) do
    # Find bracketed numeric clusters and expand ranges/commas: e.g., [1], [2-4], [5,7,9–11]
    Regex.scan(~r/\[([0-9,\s\-–]+)\]/u, strip_html(content))
    |> Enum.flat_map(fn [_, inner] -> expand_citation_inner(inner) end)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp expand_citation_inner(inner) do
    inner
    |> String.split([",", " "], trim: true)
    |> Enum.flat_map(fn part ->
      case Regex.run(~r/^(\d+)\s*[-–]\s*(\d+)$/, part) do
        [_, a, b] ->
          {a, _} = Integer.parse(a)
          {b, _} = Integer.parse(b)
          if a <= b, do: Enum.to_list(a..b), else: Enum.to_list(b..a)

        _ ->
          case Integer.parse(part) do
            {n, _} -> [n]
            _ -> []
          end
      end
    end)
  end

  # ───────────────────────────────────────────────────────────────────────────
  # Utilities
  # ───────────────────────────────────────────────────────────────────────────

  defp strip_html(s) do
    s
    # Remove code/pre blocks and inline code to avoid false positives in code samples
    |> String.replace(~r/```.*?```/ms, "")
    |> String.replace(~r/<pre[\s\S]*?<\/pre>/i, "")
    |> String.replace(~r/<code[\s\S]*?<\/code>/i, "")
    |> String.replace(~r/`[^`]*`/, "")
    # Normalize common HTML to text first
    |> String.replace(~r/<br\s*\/?>/i, "\n")
    |> String.replace(~r/<\/p>/i, "\n")
    |> String.replace(~r/<\/li>/i, "\n")
    # Strip all remaining tags
    |> String.replace(~r/<[^>]*>/, "")
  end

  defp normalize_curly_quotes(s) when is_binary(s) do
    s
    |> String.replace(~r/[\x{201C}\x{201D}]/u, "\"")
    |> String.replace(~r/[\x{2018}\x{2019}]/u, "'")
  end

  defp strip_trailing_punct(s), do: String.replace(s, @trailing_punct, "")

  defp type_rank(:doi), do: 0
  defp type_rank(:arxiv), do: 1
  defp type_rank(:url), do: 2
  defp type_rank(:isbn), do: 3
  defp type_rank(:citation), do: 4
  defp type_rank(_), do: 9
end
