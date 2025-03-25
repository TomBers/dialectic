defmodule DialecticWeb.Live.TextUtils do
  def linear_summary(content) do
    if String.starts_with?(content, "title") || String.starts_with?(content, "Title") do
      modal_title(content, "user")
    else
      truncated_html(content)
    end
  end

  def truncated_html(content, cut_off \\ 50) do
    # If content is already under the cutoff, just return the full text
    if String.length(content) <= cut_off do
      full_html(content)
    else
      truncated = String.slice(content, 0, cut_off) <> "..."
      Earmark.as_html!(truncated) |> Phoenix.HTML.raw()
    end
  end

  def full_html(content) do
    if String.starts_with?(content, "title") || String.starts_with?(content, "Title") do
      content
      |> String.split("\n", parts: 2)
      |> List.last()
      |> Earmark.as_html!()
      |> Phoenix.HTML.raw()
    else
      content |> Earmark.as_html!() |> Phoenix.HTML.raw()
    end
  end

  def modal_title(content, class) do
    if String.starts_with?(content, "title") || String.starts_with?(content, "Title") do
      extract_title(content)
    else
      String.upcase(class)
    end
  end

  def extract_title(content) do
    if String.starts_with?(content, "title") || String.starts_with?(content, "Title") do
      content
      |> String.split("\n", parts: 2)
      |> List.first()
      |> String.replace(~r/^title[:]?\s*|^Title[:]?\s*/i, "")
      |> String.trim()
    else
      content
    end
  end
end
