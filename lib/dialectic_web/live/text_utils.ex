defmodule DialecticWeb.Live.TextUtils do
  @moduledoc """
  Text parsing and rendering helpers for LiveView components.

  Prefer:
  - render_content/1 for a single-pass title + body_html result
  - process_node_content/3 for lightweight label text
  - render_preview/2 for safe truncated Markdown previews (whole-line, heading-aware)
  """

  @title_regex ~r/^title[:]?\s*|^Title[:]?\s*/i

  def parse(content) do
    norm = normalize_markdown(content)
    trimmed = String.trim(norm)

    first_line =
      norm
      |> String.split("\n")
      |> List.first()
      |> to_string()

    has_t = heading_line?(first_line) or title_prefix_line?(first_line)
    single = trimmed != "" and not String.contains?(norm, "\n")

    title =
      cond do
        has_t -> first_line |> strip_heading_or_title_prefix() |> String.trim()
        single -> first_line |> strip_heading_or_title_prefix() |> String.trim()
        true -> ""
      end

    body =
      if single do
        ""
      else
        case String.split(norm, "\n", parts: 2) do
          [_, body] ->
            text = body |> to_string() |> String.trim_leading()

            case String.split(text, "\n", parts: 2) do
              [first2, rest2] ->
                cond do
                  title_prefix_line?(first2) -> to_string(rest2)
                  heading_line?(first2) -> to_string(rest2)
                  true -> text
                end

              _ ->
                text
            end

          [only_content] ->
            only_content
        end
      end

    %{
      normalized: norm,
      first_line: first_line,
      has_title: has_t,
      title: title,
      body: body,
      single_line?: single
    }
  end

  # Private helpers

  defp normalize_markdown(content) do
    content
    |> to_string()
    |> String.replace("\r\n", "\n")
    |> String.replace("\r", "\n")
    |> String.trim_leading()
  end

  defp heading_line?(line) do
    String.match?(line, ~r/^\s*\#{1,6}\s+\S/)
  end

  defp title_prefix_line?(line) do
    String.match?(line, @title_regex)
  end

  defp strip_heading_or_title_prefix(line) do
    line
    |> String.replace(~r/^\s*\#{1,6}\s*/, "")
    |> String.replace(@title_regex, "")
  end

  @doc """
  Processes content for display in labels (e.g., node titles), mirroring the
  logic in assets/js/graph_style.js processNodeContent:

  - Remove all instances of "**"
  - Strip a leading Markdown heading marker (# .. ######) if present
  - Strip a leading "Title:" prefix (case-insensitive)
  - Use only the first line
  - Truncate to the given cutoff
  - Optionally append an ellipsis if truncated
  """
  def process_node_content(content, add_ellipsis \\ true, cutoff \\ 80) do
    full_content =
      content
      |> to_string()
      |> String.replace("**", "")

    # Use only the first line
    first_line_only =
      full_content
      |> String.split("\n")
      |> List.first()
      |> to_string()

    # Strip leading Markdown heading hashes and Title prefix if present
    line =
      strip_heading_or_title_prefix(first_line_only)

    text = String.slice(line, 0, cutoff)
    suffix = if add_ellipsis and String.length(line) > cutoff, do: "…", else: ""
    text <> suffix
  end

  @doc """
  Renders the provided content and returns a map with the extracted title and the rendered body HTML.
  This centralizes the Markdown rendering for the body to a single place.
  """
  def render_content(content) do
    p = parse(content)

    body_html =
      if p.body == "" do
        Phoenix.HTML.raw("")
      else
        p.body
        |> Earmark.as_html!()
        |> Phoenix.HTML.raw()
      end

    %{title: p.title, body_html: body_html}
  end

  @doc """
  Render a safe truncated Markdown preview as HTML, cutting only at whole-line boundaries
  and stopping before a new heading once some content has been added.

  Options:
  - :max_chars (default 200) – character budget; we add whole lines up to this budget
  - :stop_before_headings? (default true) – if true, stop when the next line is a heading
    and we have already added at least one line of content

  Returns a map: %{html: Phoenix.HTML.safe(), preview: String.t(), truncated?: boolean}
  """
  def render_preview(content, opts \\ []) do
    max_chars = Keyword.get(opts, :max_chars, 200)
    stop_before_headings? = Keyword.get(opts, :stop_before_headings?, true)

    norm = normalize_markdown(content)
    lines = String.split(to_string(norm), "\n")

    {acc, cnt, any?} =
      Enum.reduce_while(lines, {"", 0, false}, fn line, {buf, count, added_any} ->
        cond do
          stop_before_headings? and added_any and heading_line?(line) ->
            {:halt, {buf, count, added_any}}

          count == 0 and String.trim(line) == "" ->
            # Skip leading blank lines
            {:cont, {buf, count, added_any}}

          count + String.length(line) + 1 > max_chars ->
            if added_any do
              {:halt, {buf, count, added_any}}
            else
              # If nothing added yet, include the first line even if it exceeds the budget,
              # to avoid slicing mid-line
              {:halt, {buf <> line <> "\n", count + String.length(line) + 1, true}}
            end

          true ->
            {:cont, {buf <> line <> "\n", count + String.length(line) + 1, true}}
        end
      end)

    preview0 = String.trim_trailing(acc)

    preview =
      case preview0 do
        "" ->
          # Fallback to the first non-empty line (or empty string)
          Enum.find(lines, fn l -> String.trim(l) != "" end) || ""

        other ->
          other
      end

    # If we ended on a heading and we already had other content, drop the dangling heading
    preview =
      if String.contains?(preview, "\n") and heading_line?(last_nonempty_line(preview)) do
        drop_last_line(preview) |> String.trim_trailing()
      else
        preview
      end

    needs_ellipsis = String.length(norm) > String.length(preview)
    ellipsis = if needs_ellipsis, do: "\n\n…", else: ""

    html =
      (preview <> ellipsis)
      |> Earmark.as_html!()
      |> Phoenix.HTML.raw()

    %{html: html, preview: preview, truncated?: needs_ellipsis}
  end

  # Returns the last non-empty line of a string (or empty string if none)
  defp last_nonempty_line(text) do
    text
    |> String.split("\n")
    |> Enum.reverse()
    |> Enum.find("", fn l -> String.trim(l) != "" end)
  end

  # Drops the last line from a multi-line string
  defp drop_last_line(text) do
    parts = String.split(text, "\n")

    case parts do
      [] -> ""
      [_only] -> ""
      _ -> parts |> Enum.slice(0, length(parts) - 1) |> Enum.join("\n")
    end
  end
end
