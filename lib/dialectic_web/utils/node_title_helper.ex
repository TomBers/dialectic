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
      - `:max_length` - Maximum characters before truncation (default: 80)

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

  # Support both atom-key maps (%{content: ...}) and string-key maps (%{"content" => ...})
  defp get_content(%{content: content}), do: content
  defp get_content(%{"content" => content}), do: content
  defp get_content(_), do: nil

  defp get_id(%{id: id}), do: id
  defp get_id(%{"id" => id}), do: id
  defp get_id(_), do: nil
end
