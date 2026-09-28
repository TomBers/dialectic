defmodule Dialectic.Learning.Search do
  import Ecto.Query

  alias Dialectic.Accounts.Graph
  alias Dialectic.Highlights.Highlight
  alias Dialectic.Repo
  alias DialecticWeb.{ColUtils, NodeSearch}

  def filter(query, _user, ""), do: query

  def filter(query, user, term) do
    pattern = "%" <> String.replace(term, ~r/[\\%_]/, fn char -> "\\" <> char end) <> "%"

    highlighted =
      from h in Highlight,
        where: h.created_by_user_id == ^user.id,
        where: ilike(h.selected_text_snapshot, ^pattern) or ilike(h.note, ^pattern),
        select: h.mudg_id

    from g in query,
      where:
        ilike(g.title, ^pattern) or
          ilike(fragment("array_to_string(?, ' ')", g.tags), ^pattern) or
          g.title in subquery(highlighted) or
          fragment(
            """
            EXISTS (
              SELECT 1 FROM jsonb_array_elements(
                CASE WHEN jsonb_typeof(?->'nodes') = 'array' THEN ?->'nodes' ELSE '[]'::jsonb END
              ) AS node
              WHERE COALESCE(node->>'deleted', 'false') <> 'true'
                AND (node->>'content' ILIKE ? OR node->>'source_text' ILIKE ?)
            )
            """,
            g.data,
            g.data,
            ^pattern,
            ^pattern
          )
  end

  def add_matches(grids, ""), do: Enum.map(grids, &Map.put(&1, :search_matches, []))

  def add_matches(grids, term) do
    titles = Enum.map(grids, & &1.title)

    data =
      Repo.all(from g in Graph, where: g.title in ^titles, select: {g.title, g.data}) |> Map.new()

    Enum.map(grids, fn grid ->
      highlight_matches =
        Enum.flat_map(grid.highlights, fn highlight ->
          text =
            Enum.find([highlight.selected_text_snapshot, highlight.note], &matches?(&1, term))

          if text do
            [
              %{
                node_id: highlight.node_id,
                highlight_id: highlight.id,
                label: "Highlight",
                preview: preview(text, term)
              }
            ]
          else
            []
          end
        end)

      node_matches =
        (get_in(data, [grid.title, "nodes"]) || [])
        |> Enum.reject(&(Map.get(&1, "deleted") in [true, "true"]))
        |> Enum.flat_map(fn node ->
          field = Enum.find(["content", "source_text"], &matches?(node[&1], term))

          if field do
            [
              %{
                node_id: node["id"],
                highlight_id: nil,
                label: match_label(field, node["class"]),
                preview: preview(node[field], term)
              }
            ]
          else
            []
          end
        end)

      Map.put(grid, :search_matches, Enum.take(highlight_matches ++ node_matches, 3))
    end)
  end

  defp match_label("source_text", _class), do: "Source"
  defp match_label("content", "origin"), do: "Starting question"
  defp match_label("content", class), do: ColUtils.node_type_label(class)

  defp matches?(text, term) when is_binary(text),
    do: String.contains?(String.downcase(text), String.downcase(term))

  defp matches?(_text, _term), do: false

  defp preview(text, term) do
    case NodeSearch.annotate_result(%{"id" => "preview", "content" => text}, term) do
      %{search_preview: preview} when is_binary(preview) -> preview
      _ -> String.slice(text, 0, 180)
    end
  end
end
