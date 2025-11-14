defmodule DialecticWeb.Live.TextUtils do
  @moduledoc """
  Text parsing and rendering helpers for LiveView components.

  Prefer:
  - render_content/1 for a single-pass title + body_html result
  - process_node_content/3 for lightweight label text
  """

  @title_regex ~r/^title[:]?\s*|^Title[:]?\s*/i

  @spec parse(String.t() | nil) :: %{
          normalized: String.t(),
          first_line: String.t(),
          has_title: boolean(),
          title: String.t(),
          body: String.t(),
          single_line?: boolean()
        }
  def parse(content) do
    norm = normalize_markdown(content)
    trimmed = String.trim(norm)

    first_line =
      norm
      |> String.split("\n")
      |> List.first("")

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
            text = String.trim_leading(body)

            case String.split(text, "\n", parts: 2) do
              [first2, rest2] ->
                cond do
                  title_prefix_line?(first2) -> rest2
                  heading_line?(first2) -> rest2
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

  @spec normalize_markdown(String.t() | nil) :: String.t()
  defp normalize_markdown(content) do
    (content || "")
    |> String.replace(~r/\r\n|\r/, "\n")
    |> String.trim_leading()
  end

  @spec heading_line?(String.t()) :: boolean()
  defp heading_line?(line) do
    String.match?(line, ~r/^\s*\#{1,6}\s+\S/)
  end

  @spec title_prefix_line?(String.t()) :: boolean()
  defp title_prefix_line?(line) do
    String.match?(line, @title_regex)
  end

  @spec strip_heading_or_title_prefix(String.t()) :: String.t()
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
  @spec process_node_content(String.t() | nil, boolean(), non_neg_integer()) :: String.t()
  def process_node_content(content, add_ellipsis \\ true, cutoff \\ 80) do
    full_content =
      (content || "")
      |> String.replace("**", "")

    # Use only the first line
    first_line_only =
      full_content
      |> String.split("\n")
      |> List.first("")

    # Strip leading Markdown heading hashes, Title prefix, and prompt labels if present
    line =
      first_line_only
      |> strip_heading_or_title_prefix()

    text = String.slice(line, 0, cutoff)
    suffix = if add_ellipsis and String.length(line) > cutoff, do: "…", else: ""
    text <> suffix
  end

  @doc """
  Renders the provided content and returns a map with:
  - title
  - body_html: stable rendered markdown + a raw-text tail block (for immediate feedback)
  - stable_html: only the rendered stable portion
  - tail_text: the trailing, possibly malformed text (unrendered)
  """
  @spec render_content(String.t() | nil) :: map()
  def render_content(content) do
    p = parse(content)
    body = p.body || ""

    {stable, tail} = split_stable_tail(body)

    stable_html =
      if stable == "" do
        ""
      else
        stable
        |> strip_forbidden_blocks()
        |> fix_unclosed_fences()
        |> fix_unbalanced_emphasis()
        |> render_markdown_html()
      end

    tail_html =
      if tail == "" do
        ""
      else
        "<pre class=\"whitespace-pre-wrap font-mono text-sm text-gray-800\">" <>
          html_escape(tail) <> "</pre>"
      end

    combined_html = stable_html <> tail_html

    # Sanitize title to remove Markdown headings and leading prompt labels from past data
    sanitized_title =
      p.title
      |> String.replace(~r/^\s*#+\s*/, "")

    %{
      title: sanitized_title,
      body_html: Phoenix.HTML.raw(combined_html),
      stable_html: Phoenix.HTML.raw(stable_html),
      tail_text: tail
    }
  end

  # --- Robust streaming helpers ---

  # Split the buffer into stable and tail so that the stable portion never ends inside an open code fence.
  # Also prefer to cut the stable portion on a paragraph boundary (double newline) when possible.
  @doc false
  defp split_stable_tail(buffer) do
    buf = to_string(buffer || "")

    if buf == "" do
      {"", ""}
    else
      fence_positions =
        Regex.scan(~r/```/, buf, return: :index)
        |> Enum.map(fn [pos] -> elem(pos, 0) end)

      {stable_candidate, tail_after_fence} =
        if rem(length(fence_positions), 2) == 1 do
          # Odd number of backtick fences => last is an opening fence; move it (and after) to tail
          last_open = List.last(fence_positions)

          {binary_part(buf, 0, last_open),
           binary_part(buf, last_open, byte_size(buf) - last_open)}
        else
          {buf, ""}
        end

      # Prefer splitting stable on the last paragraph boundary to reduce mid-token artifacts.
      para_matches = :binary.matches(stable_candidate, "\n\n")

      stable_len =
        case para_matches do
          [] ->
            byte_size(stable_candidate)

          list ->
            {pos, _} = List.last(list)
            pos + 2
        end

      stable = binary_part(stable_candidate, 0, stable_len)

      tail =
        binary_part(stable_candidate, stable_len, byte_size(stable_candidate) - stable_len) <>
          tail_after_fence

      {stable, tail}
    end
  end

  defp render_markdown_html(markdown) do
    opts = %Earmark.Options{code_class_prefix: "lang-", smartypants: false, escape: true}

    case Earmark.as_html(markdown, opts) do
      {:ok, html_doc, _warnings} -> html_doc
      {:error, html_doc, _messages} -> html_doc
    end
  end

  # Remove/neutralize constructs we disallow or that often break parsing.
  defp strip_forbidden_blocks(markdown) do
    markdown
    |> strip_tables()
    |> replace_images()
    |> remove_inline_html()
  end

  # Treat lines that look like table rows as plain text.
  defp strip_tables(markdown) do
    markdown
    |> String.split("\n", trim: false)
    |> Enum.map(fn line ->
      if String.match?(line, ~r/^\|.*\|/) do
        "Table row (rendered as text): " <> line
      else
        line
      end
    end)
    |> Enum.join("\n")
  end

  # Replace images like ![alt](url) with a simple placeholder.
  defp replace_images(markdown) do
    Regex.replace(~r/!\[[^\]]*\]\([^)]+\)/, markdown, "[image omitted]")
  end

  # Escape inline HTML tags outside fenced code blocks to prevent raw HTML rendering.
  defp remove_inline_html(markdown) do
    {outside, inside} = split_outside_inside_fences(markdown)

    repaired_outside =
      Enum.map(outside, fn seg ->
        seg
        |> String.replace("&", "&amp;")
        |> String.replace("<", "&lt;")
        |> String.replace(">", "&gt;")
      end)
      |> Enum.join("")

    merge_outside_inside(repaired_outside, inside)
  end

  # Close unclosed code fences (render-only).
  defp fix_unclosed_fences(markdown) do
    fence_count = Regex.scan(~r/```/, markdown) |> length()

    if rem(fence_count, 2) == 1 do
      markdown <> "\n```"
    else
      markdown
    end
  end

  # Balance ** and * markers outside fenced code blocks (render-only).
  defp fix_unbalanced_emphasis(markdown) do
    {outside, inside} = split_outside_inside_fences(markdown)

    {fixed_outside, need_double?, need_single?} =
      Enum.reduce(outside, {"", false, false}, fn seg, {acc, dbl?, sgl?} ->
        dbl_imbalance = rem(count(seg, "**"), 2) == 1
        sgl_imbalance = rem(count(seg, "*") - 2 * count(seg, "**"), 2) == 1
        {acc <> seg, dbl? or dbl_imbalance, sgl? or sgl_imbalance}
      end)

    repaired =
      fixed_outside <>
        if(need_double?, do: "**", else: "") <>
        if need_single?, do: "*", else: ""

    merge_outside_inside(repaired, inside)
  end

  # Split the markdown into alternating outside/inside fenced segments.
  # Returns {outside_segments, inside_fence_segments}
  defp split_outside_inside_fences(markdown) do
    parts = Regex.split(~r/(```.*?```)/s, markdown, include_captures: true)
    indexed = Enum.with_index(parts)
    outside = for {seg, idx} <- indexed, rem(idx, 2) == 0, do: seg
    inside = for {seg, idx} <- indexed, rem(idx, 2) == 1, do: seg
    {outside, inside}
  end

  defp merge_outside_inside(outside_joined, inside_segments) do
    outside_joined <> Enum.join(inside_segments, "")
  end

  defp count(haystack, needle) do
    haystack
    |> :binary.matches(needle)
    |> length()
  end

  defp html_escape(text) do
    to_string(text || "")
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
  end
end
