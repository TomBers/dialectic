defmodule DialecticWeb.Utils.NodeTitleHelper do
  @moduledoc """
  Shared utilities for extracting readable titles from node content.
  """

  @doc """
  Extracts a readable title from node content.

  Takes the first line of content, strips markdown formatting (headers, bold),
  and truncates to a reasonable length.

  ## Parameters
    - node: A map with `:content` key (string) and optionally `:id` key
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

    case node do
      %{content: content} when is_binary(content) and content != "" ->
        content
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
            Map.get(node, :id, "Untitled")

          title ->
            String.slice(title, 0, max_length) <>
              if String.length(title) > max_length, do: "...", else: ""
        end

      _ ->
        if is_map(node) && Map.get(node, :id), do: Map.get(node, :id), else: "Untitled"
    end
  end
end
