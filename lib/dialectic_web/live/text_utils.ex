defmodule DialecticWeb.Live.TextUtils do
  @moduledoc """
  Utilities for text processing and formatting in LiveView components.
  """

  @title_regex ~r/^title[:]?\s*|^Title[:]?\s*/i

  @doc """
  Creates a linear summary of content, extracting the title if it exists,
  or creating a truncated HTML representation otherwise.
  """
  def linear_summary(content) do
    if has_title?(content) do
      modal_title(content, "user")
    else
      truncated_html(content)
    end
  end

  @doc """
  Truncates content to specified length and converts to HTML.
  """
  def truncated_html(content, cut_off \\ 50) do
    content
    |> normalize_markdown()
    |> String.slice(0, cut_off)
    |> full_html(" ...")
  end

  @doc """
  Converts content to full HTML, handling title extraction if needed.
  """
  def full_html(content, end_string \\ "") do
    norm = normalize_markdown(content)

    if has_title?(norm) do
      (norm <> end_string)
      |> extract_content_body()
      |> Earmark.as_html!()
      |> Phoenix.HTML.raw()
    else
      norm |> Earmark.as_html!() |> Phoenix.HTML.raw()
    end
  end

  @doc """
  Extracts a modal title from content or uses a class-based default.
  """
  def modal_title(content, _class \\ "") do
    if has_title?(content) do
      extract_title(content)
    else
      ""
    end
  end

  @doc """
  Extracts title from content if one exists.
  """
  def extract_title(content) do
    if has_title?(content) do
      content
      |> to_string()
      |> String.trim_leading()
      |> String.split("\n", parts: 2)
      |> List.first()
      |> String.replace(~r/^\s*\#{1,6}\s*/, "")
      |> String.replace(@title_regex, "")
      |> String.trim()
    else
      content
    end
  end

  # Private helpers

  defp normalize_markdown(content) do
    content
    |> to_string()
    |> String.replace("\r\n", "\n")
    |> String.replace("\r", "\n")
    |> String.trim_leading()
  end

  defp has_title?(content) do
    first_line =
      content
      |> to_string()
      |> String.trim_leading()
      |> String.split("\n", parts: 2)
      |> List.first()

    cond do
      is_nil(first_line) -> false
      Regex.match?(~r/^\s*\#{1,6}\s+\S/, first_line) -> true
      Regex.match?(~r/^title\s*:?\s*/i, first_line) -> true
      true -> false
    end
  end

  defp extract_content_body(content) do
    case content |> to_string() |> String.trim_leading() |> String.split("\n", parts: 2) do
      [_, body] ->
        text = body |> to_string() |> String.trim_leading()

        case String.split(text, "\n", parts: 2) do
          [first, rest] ->
            cond do
              Regex.match?(~r/^title\s*:?\s*/i, first) -> to_string(rest || "")
              Regex.match?(~r/^\s*\#{1,6}\s+\S/, first) -> to_string(rest || "")
              true -> text
            end

          _ ->
            text
        end

      [only_content] ->
        only_content
    end
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

    # Strip leading Markdown heading hashes (e.g., "## ")
    no_heading =
      Regex.replace(~r/^\s*\#{1,6}\s*/, first_line_only, "")

    # Remove "Title:" prefix if present (case-insensitive)
    line =
      Regex.replace(~r/^Title:\s*/i, no_heading, "")

    text = String.slice(line, 0, cutoff)
    suffix = if add_ellipsis and String.length(line) > cutoff, do: "…", else: ""
    text <> suffix
  end
end
