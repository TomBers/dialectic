defmodule Dialectic.Search do
  @moduledoc false

  import Ecto.Query

  alias Dialectic.Accounts.Graph
  alias Dialectic.Accounts.User
  alias Dialectic.Repo
  alias DialecticWeb.NodeSearch

  @default_limit 12
  @matches_per_graph 3
  @candidate_multiplier 12
  @max_query_length 100

  def search_public(query, opts \\ []) do
    query = normalize_query(query)

    if String.length(query) < 3 do
      []
    else
      limit = Keyword.get(opts, :limit, @default_limit)
      pattern = contains_pattern(query)

      pattern
      |> title_matches(query)
      |> add_node_matches(node_matches(pattern, limit), query)
      |> prepare_results(query)
      |> Enum.take(limit)
    end
  end

  def normalize_query(query) do
    query
    |> to_string()
    |> String.trim()
    |> String.replace(~r/\s+/u, " ")
    |> String.slice(0, @max_query_length)
  end

  defp title_matches(pattern, query) do
    from(g in Graph,
      left_join: author in User,
      on: author.id == g.user_id,
      where: g.is_public == true,
      where: g.is_published == true,
      where: g.is_deleted == false or is_nil(g.is_deleted),
      where:
        fragment("? ILIKE ? ESCAPE E'\\\\'", g.title, ^pattern) or
          fragment(
            "EXISTS (SELECT 1 FROM unnest(?) AS graph_tag(value) WHERE graph_tag.value ILIKE ? ESCAPE E'\\\\')",
            g.tags,
            ^pattern
          ),
      select: %{
        graph_title: g.title,
        graph_slug: g.slug,
        graph_tags: g.tags,
        graph_is_public: g.is_public,
        author_name: author.username
      }
    )
    |> Repo.all()
    |> Map.new(fn row ->
      graph = graph_from_row(row)

      {row.graph_title,
       %{
         graph: graph,
         author_name: row.author_name,
         match_reason: graph_match_reason(graph, query),
         matches: []
       }}
    end)
  end

  defp node_matches(pattern, limit) do
    candidate_limit = max(limit * @candidate_multiplier, 100)

    from(g in Graph,
      inner_lateral_join:
        node in fragment(
          "jsonb_array_elements(CASE WHEN jsonb_typeof(?->'nodes') = 'array' THEN ?->'nodes' ELSE '[]'::jsonb END)",
          g.data,
          g.data
        ),
      on: true,
      left_join: author in User,
      on: author.id == g.user_id,
      where: g.is_public == true,
      where: g.is_published == true,
      where: g.is_deleted == false or is_nil(g.is_deleted),
      where: fragment("COALESCE((?->>'deleted')::boolean, false) = false", node),
      where:
        fragment("COALESCE(?->>'content', '') ILIKE ? ESCAPE E'\\\\'", node, ^pattern) or
          fragment(
            "COALESCE(?->>'source_text', '') ILIKE ? ESCAPE E'\\\\'",
            node,
            ^pattern
          ),
      order_by: [desc: g.updated_at],
      limit: ^candidate_limit,
      select: %{
        graph_title: g.title,
        graph_slug: g.slug,
        graph_tags: g.tags,
        graph_is_public: g.is_public,
        author_name: author.username,
        node: fragment("?::jsonb", node)
      }
    )
    |> Repo.all()
  end

  defp add_node_matches(results, rows, query) do
    Enum.reduce(rows, results, fn row, acc ->
      case NodeSearch.annotate_result(row.node, query) do
        nil ->
          acc

        match ->
          Map.update(
            acc,
            row.graph_title,
            %{
              graph: graph_from_row(row),
              author_name: row.author_name,
              match_reason: nil,
              matches: [match]
            },
            fn result -> %{result | matches: [match | result.matches]} end
          )
      end
    end)
  end

  defp prepare_results(results, query) do
    results
    |> Map.values()
    |> Enum.map(fn result ->
      matches =
        result.matches
        |> Enum.uniq_by(&node_id/1)
        |> Enum.sort_by(&Map.get(&1, :search_rank, {9, 9}))
        |> Enum.take(@matches_per_graph)

      %{result | matches: matches}
    end)
    |> Enum.sort_by(&result_rank(&1, query))
  end

  defp result_rank(%{match_reason: reason, graph: graph}, query) when not is_nil(reason) do
    title = graph.title |> String.downcase()
    query = String.downcase(query)

    title_rank =
      cond do
        title == query -> 0
        String.starts_with?(title, query) -> 1
        reason == :title -> 2
        true -> 3
      end

    {0, title_rank, title}
  end

  defp result_rank(%{matches: [match | _], graph: graph}, _query) do
    {1, Map.get(match, :search_rank, {9, 9}), String.downcase(graph.title)}
  end

  defp result_rank(%{graph: graph}, _query), do: {2, {9, 9}, String.downcase(graph.title)}

  defp graph_match_reason(graph, query) do
    query = String.downcase(query)

    cond do
      String.contains?(String.downcase(graph.title), query) -> :title
      Enum.any?(graph.tags, &String.contains?(String.downcase(&1), query)) -> :topic
      true -> nil
    end
  end

  defp graph_from_row(row) do
    %{
      title: row.graph_title,
      slug: row.graph_slug,
      tags: row.graph_tags || [],
      is_public: row.graph_is_public
    }
  end

  defp node_id(node), do: Map.get(node, :id) || Map.get(node, "id")

  defp contains_pattern(query), do: "%" <> escape_like(query) <> "%"

  defp escape_like(query) do
    query
    |> String.replace("\\", "\\\\")
    |> String.replace("%", "\\%")
    |> String.replace("_", "\\_")
  end
end
