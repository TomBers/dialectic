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
  @spec render_content(String.t() | nil) :: map()
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
end
