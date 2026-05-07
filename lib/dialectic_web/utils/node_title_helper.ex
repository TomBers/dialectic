defmodule DialecticWeb.Utils.NodeTitleHelper do
  @moduledoc """
  Shared utilities for extracting readable titles from node content.
  """

  @doc """
  Extracts a readable title from node content.

  Takes the first line of content, strips markdown formatting (headers, bold),
  and truncates to a reasonable length.

  ## Parameters
    - node: A map with `:content` or `"content"` key (string) and optionally `:id` or `"id"` key.
            Supports both atom-keyed structs and string-keyed maps (e.g. from JSON).
    - opts: Keyword list of options
      - `:max_length` - Maximum characters before truncation (default: 80).
        Can also be `nil` or `:infinity` to disable truncation entirely.

  ## Examples
      iex> extract_node_title(%{content: "# Hello World\\nMore text"})
      "Hello World"

      iex> extract_node_title(%{content: "## Title: Something\\nBody"}, max_length: 10)
      "Something..."

      iex> extract_node_title(%{content: "", id: "123"})
      "123"
  """
  def extract_node_title(node, opts \\ []) do
    max_length = Keyword.get(opts, :max_length, 80)

    content = get_content(node)
    node_id = get_id(node)

    case content do
      c when is_binary(c) and c != "" ->
        c
        |> String.replace(~r/\r\n|\r/, "\n")
        |> String.split("\n")
        |> List.first()
        |> Kernel.||("")
        |> String.replace(~r/^\s*\#{1,6}\s*/, "")
        |> String.replace(~r/^\s*title\s*:?\s*/i, "")
        |> String.replace("**", "")
        |> String.trim()
        |> case do
          "" ->
            node_id || "Untitled"

          title ->
            if max_length in [nil, :infinity] do
              title
            else
              String.slice(title, 0, max_length) <>
                if String.length(title) > max_length, do: "...", else: ""
            end
        end

      _ ->
        node_id || "Untitled"
    end
  end

  @doc """
  Extracts a preview snippet around a matching search term in the node content.

  Returns a tuple of `{before_match, matched_text, after_match}` that can be used
  to render the preview with the match highlighted. Returns `nil` if no match found.

  ## Parameters
    - node: A map with `:content` or `"content"` key
    - search_term: The search term to find (case-insensitive)
    - opts: Keyword list of options
      - `:context_chars` - Number of characters to show before/after match (default: 40)

  ## Examples
      iex> extract_match_preview(%{content: "Hello world, this is a test"}, "world")
      {"Hello ", "world", ", this is a test"}

      iex> extract_match_preview(%{content: "Some long text here"}, "missing")
      nil
  """
  def extract_match_preview(node, search_term, opts \\ []) do
    context_chars = Keyword.get(opts, :context_chars, 40)
    content = get_content(node) || ""

    # Normalize content: collapse multiple whitespace/newlines to single space
    normalized_content =
      content
      |> String.replace(~r/\s+/, " ")
      |> String.trim()

    term_lower = String.downcase(search_term)
    content_lower = String.downcase(normalized_content)

    case :binary.match(content_lower, term_lower) do
      :nomatch ->
        nil

      {start_pos, match_length} ->
        # Extract the actual matched text (preserving original case)
        matched_text = String.slice(normalized_content, start_pos, match_length)

        # Calculate context boundaries
        before_start = max(0, start_pos - context_chars)

        after_end =
          min(String.length(normalized_content), start_pos + match_length + context_chars)

        # Extract before and after text
        before_text = String.slice(normalized_content, before_start, start_pos - before_start)

        after_text =
          String.slice(
            normalized_content,
            start_pos + match_length,
            after_end - start_pos - match_length
          )

        # Add ellipsis if we're not at the boundaries
        before_text = if before_start > 0, do: "…" <> before_text, else: before_text

        after_text =
          if after_end < String.length(normalized_content),
            do: after_text <> "…",
            else: after_text

        {before_text, matched_text, after_text}
    end
  end

  # Support both atom-key maps (%{content: ...}) and string-key maps (%{"content" => ...})
  defp get_content(%{content: content}), do: content
  defp get_content(%{"content" => content}), do: content
  defp get_content(_), do: nil

  defp get_id(%{id: id}), do: id
  defp get_id(%{"id" => id}), do: id
  defp get_id(_), do: nil
end
