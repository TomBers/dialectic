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
    |> String.slice(0, cut_off)
    |> full_html(" ...")
  end

  @doc """
  Converts content to full HTML, handling title extraction if needed.
  """
  def full_html(content, end_string \\ "") do
    if has_title?(content) do
      (content <> end_string)
      |> extract_content_body()
      |> Earmark.as_html!()
      |> Phoenix.HTML.raw()
    else
      content |> Earmark.as_html!() |> Phoenix.HTML.raw()
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
      |> String.split("\n", parts: 2)
      |> List.first()
      |> String.replace(@title_regex, "")
      |> String.trim()
    else
      content
    end
  end

  # Private helpers

  defp has_title?(content) do
    String.match?(content, ~r/^title[:"]?|^Title[:"]?/i)
  end

  defp extract_content_body(content) do
    case String.split(content, "\n", parts: 2) do
      [_, body] -> body
      [only_content] -> only_content
    end
  end
end
