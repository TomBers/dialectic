defmodule Dialectic.Graph.StructuralRoot do
  @moduledoc false

  @root_id "1"

  def root_id, do: @root_id

  def structural?(nil, _graph_title), do: false
  def structural?(_node, nil), do: false

  def structural?(%{id: @root_id, class: "origin", content: content}, graph_title) do
    title_only_content?(content, graph_title)
  end

  def structural?(_node, _graph_title), do: false

  def root_id_if_structural(graph, graph_title) do
    case :digraph.vertex(graph, @root_id) do
      {@root_id, node} ->
        if structural?(node, graph_title), do: @root_id

      _ ->
        nil
    end
  end

  def title_only_content?(content, graph_title)
      when is_binary(content) and is_binary(graph_title) do
    lines =
      content
      |> String.trim()
      |> String.split("\n")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    case lines do
      [line] -> normalize_title_line(line) == normalize_title_line(graph_title)
      _ -> false
    end
  end

  def title_only_content?(_content, _graph_title), do: false

  defp normalize_title_line(line) do
    line
    |> String.trim()
    |> String.replace(~r/^\s{0,3}\#{1,6}\s+/, "")
    |> String.replace(~r/\s+#+\s*$/, "")
    |> String.trim()
    |> String.downcase()
  end
end
