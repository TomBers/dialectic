defmodule DialecticWeb.NodeSearch do
  @moduledoc false

  alias DialecticWeb.ColUtils
  alias DialecticWeb.Utils.NodeTitleHelper

  @preview_limit 150

  def annotate_result(node, search_term) do
    normalized_term = normalize_search_term(search_term)

    if normalized_term == "" do
      nil
    else
      prepared_node = prepare_node(node)

      case best_match(prepared_node, normalized_term) do
        nil ->
          nil

        %{field: field, rank: rank} ->
          prepared_node
          |> Map.put(:search_preview, preview_snippet(field.text, search_term))
          |> Map.put(:search_preview_label, field.label)
          |> Map.put(:search_rank, rank)
      end
    end
  end

  defp prepare_node(node) do
    title =
      case Map.get(node, :title) do
        value when is_binary(value) and value != "" -> value
        _ -> display_title(node)
      end

    full_title =
      case Map.get(node, :full_title) do
        value when is_binary(value) and value != "" -> value
        _ -> display_title(node, max_length: :infinity)
      end

    body_content =
      case Map.get(node, :body_content) do
        value when is_binary(value) -> value
        _ -> node_body_content(node)
      end

    node
    |> Map.put(:title, title)
    |> Map.put(:full_title, full_title)
    |> Map.put(:body_content, body_content)
    |> Map.put_new(:class, Map.get(node, :class, "default"))
  end

  defp best_match(node, normalized_term) do
    node
    |> search_fields()
    |> Enum.reduce(nil, fn field, best ->
      case field_match_rank(field.text, normalized_term) do
        nil ->
          best

        field_rank ->
          candidate = %{field: field, rank: {field.priority, field_rank}}

          case best do
            nil -> candidate
            %{rank: best_rank} when candidate.rank < best_rank -> candidate
            _ -> best
          end
      end
    end)
  end

  defp search_fields(node) do
    content =
      Map.get(node, :content) ||
        Map.get(node, "content") ||
        ""

    source_text =
      Map.get(node, :source_text) ||
        Map.get(node, "source_text") ||
        ""

    body_content = Map.get(node, :body_content) || ""

    content_preview =
      if String.trim(body_content) == "" do
        content
      else
        body_content
      end

    [
      %{label: "Title", text: Map.get(node, :full_title) || "", priority: 0},
      %{label: "Content", text: content_preview, priority: 1},
      %{label: "Source", text: source_text, priority: 2}
    ]
    |> Enum.reject(fn field -> sanitize_preview_text(field.text) == "" end)
  end

  defp field_match_rank(text, normalized_term) do
    searchable_text =
      text
      |> sanitize_preview_text()
      |> String.downcase()

    cond do
      searchable_text == "" -> nil
      searchable_text == normalized_term -> 0
      String.starts_with?(searchable_text, normalized_term) -> 1
      String.contains?(searchable_text, normalized_term) -> 2
      true -> nil
    end
  end

  defp display_title(node, opts \\ []) do
    title = NodeTitleHelper.extract_node_title(node, opts)
    node_id = Map.get(node, :id) || Map.get(node, "id")
    content = Map.get(node, :content) || Map.get(node, "content") || ""

    cond do
      is_binary(title) and String.trim(title) != "" and String.trim(content) != "" ->
        title

      is_binary(title) and String.trim(title) != "" and title != to_string(node_id || "") ->
        title

      true ->
        fallback_title(node)
    end
  end

  defp fallback_title(node) do
    "Untitled " <>
      String.downcase(
        ColUtils.node_type_label(Map.get(node, :class) || Map.get(node, "class") || "default")
      )
  end

  defp preview_snippet(text, search_term, limit \\ @preview_limit) do
    cleaned_text = sanitize_preview_text(text)
    normalized_term = normalize_search_term(search_term)

    cond do
      cleaned_text == "" ->
        nil

      normalized_term == "" ->
        truncate_preview(cleaned_text, limit)

      true ->
        snippet_from_match(cleaned_text, normalized_term, limit)
    end
  end

  defp snippet_from_match(cleaned_text, normalized_term, limit) do
    context_window = max(div(limit, 2) - String.length(normalized_term), 28)

    regex =
      Regex.compile!(
        "(.{0,#{context_window}}#{Regex.escape(normalized_term)}.{0,#{context_window}})",
        "iu"
      )

    case Regex.run(regex, cleaned_text, capture: :all_but_first) do
      [snippet] ->
        snippet = String.trim(snippet)

        [
          if(String.starts_with?(cleaned_text, snippet), do: "", else: "…"),
          snippet,
          if(String.ends_with?(cleaned_text, snippet), do: "", else: "…")
        ]
        |> Enum.join()

      _ ->
        truncate_preview(cleaned_text, limit)
    end
  end

  defp truncate_preview(text, limit) do
    if String.length(text) > limit do
      String.slice(text, 0, limit) <> "…"
    else
      text
    end
  end

  defp normalize_search_term(search_term) do
    search_term
    |> sanitize_preview_text()
    |> String.downcase()
  end

  defp node_body_content(node) do
    node
    |> then(fn current_node ->
      Map.get(current_node, :content) || Map.get(current_node, "content") || ""
    end)
    |> extract_body_content()
  end

  defp extract_body_content(content) do
    normalized_content =
      content
      |> to_string()
      |> String.replace(~r/\r\n|\r/, "\n")

    rest =
      normalized_content
      |> String.split("\n")
      |> Enum.drop(1)
      |> Enum.join("\n")
      |> String.trim_leading()

    case String.split(rest, "\n") do
      [first_line | remaining_lines] ->
        if String.match?(first_line, ~r/^\s*\#{1,6}\s+\S/) or
             String.match?(first_line, ~r/^\s*(title|Title)\s*:?\s*/) do
          Enum.join(remaining_lines, "\n")
        else
          rest
        end

      [] ->
        rest
    end
    |> String.trim()
  end

  defp sanitize_preview_text(content) do
    content
    |> to_string()
    |> String.replace(~r/\r\n|\r/, "\n")
    |> String.replace(~r/!\[([^\]]*)\]\([^)]+\)/u, "\\1")
    |> String.replace(~r/\[([^\]]+)\]\([^)]+\)/u, "\\1")
    |> String.replace(~r/^\s*\#{1,6}\s*/mu, "")
    |> String.replace(~r/^\s*>\s?/mu, "")
    |> String.replace(~r/[*_`~]/u, "")
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end
end
