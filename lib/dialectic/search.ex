defmodule Dialectic.Search do
  @moduledoc false

  import Ecto.Query

  alias Dialectic.Accounts.Graph
  alias Dialectic.Accounts.User
  alias Dialectic.Repo
  alias Dialectic.Search.Document
  alias Dialectic.Search.Query
  alias DialecticWeb.NodeSearch

  @default_limit 12
  @matches_per_graph 3
  @max_query_length 100

  def search_public(query, opts \\ []) do
    query = normalize_query(query)

    if String.length(query) < 2 do
      []
    else
      limit = Keyword.get(opts, :limit, @default_limit)
      offset = Keyword.get(opts, :offset, 0)
      terms = Query.terms(query)
      graph_titles = candidate_graph_titles(terms, query, limit, offset)

      graph_titles
      |> graph_results(query)
      |> add_node_matches(node_matches(terms, query, graph_titles), query)
      |> prepare_results(query)
    end
  end

  def normalize_query(query) do
    query
    |> to_string()
    |> String.trim()
    |> String.replace(~r/\s+/u, " ")
    |> String.slice(0, @max_query_length)
  end

  defp candidate_graph_titles(terms, query, limit, offset) do
    match = match_expression(terms)

    from(document in Document,
      join: graph in Graph,
      on: graph.title == document.graph_title,
      where: graph.is_public == true,
      where: graph.is_published == true,
      where: graph.is_deleted == false or is_nil(graph.is_deleted),
      where: ^match,
      group_by: document.graph_title,
      order_by: [
        asc: fragment("min(CASE WHEN ? = 'graph' THEN 0 ELSE 1 END)", document.kind),
        desc: fragment("max(similarity(?, ?))", document.search_text, ^query),
        asc: document.graph_title
      ],
      limit: ^limit,
      offset: ^offset,
      select: document.graph_title
    )
    |> Repo.all()
  end

  defp graph_results([], _query), do: %{}

  defp graph_results(graph_titles, query) do
    from(graph in Graph,
      left_join: author in User,
      on: author.id == graph.user_id,
      where: graph.title in ^graph_titles,
      where: graph.is_public == true,
      where: graph.is_published == true,
      where: graph.is_deleted == false or is_nil(graph.is_deleted),
      select: %{
        graph_title: graph.title,
        graph_slug: graph.slug,
        graph_tags: graph.tags,
        graph_is_public: graph.is_public,
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

  defp node_matches(_terms, _query, []), do: []

  defp node_matches(terms, query, graph_titles) do
    match = match_expression(terms)

    ranked_documents =
      from(document in Document,
        where: document.graph_title in ^graph_titles,
        where: document.kind == "node",
        where: ^match,
        windows: [
          per_graph: [
            partition_by: document.graph_title,
            order_by: [
              desc: fragment("similarity(?, ?)", document.search_text, ^query),
              asc: document.node_id
            ]
          ]
        ],
        select: %{
          graph_title: document.graph_title,
          node_id: document.node_id,
          content: document.content,
          source_text: document.source_text,
          row_number: over(row_number(), :per_graph)
        }
      )

    from(document in subquery(ranked_documents),
      where: document.row_number <= ^@matches_per_graph,
      order_by: [asc: document.graph_title, asc: document.row_number],
      select: %{
        graph_title: document.graph_title,
        node_id: document.node_id,
        content: document.content,
        source_text: document.source_text
      }
    )
    |> Repo.all()
  end

  defp add_node_matches(results, rows, query) do
    Enum.reduce(rows, results, fn row, acc ->
      node = %{
        "id" => row.node_id,
        "content" => row.content,
        "source_text" => row.source_text,
        "class" => "default",
        "deleted" => false
      }

      match =
        NodeSearch.annotate_result(node, query) ||
          Enum.find_value(Query.terms(query), &NodeSearch.annotate_result(node, &1))

      case match do
        nil ->
          acc

        match ->
          case Map.fetch(acc, row.graph_title) do
            {:ok, result} ->
              Map.put(acc, row.graph_title, %{result | matches: [match | result.matches]})

            :error ->
              acc
          end
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

      %{result | matches: matches}
    end)
    |> Enum.reject(fn result -> is_nil(result.match_reason) and result.matches == [] end)
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
    terms = Query.terms(query)

    cond do
      Query.matches?(graph.title, terms) -> :title
      Query.matches?(Enum.join(graph.tags, " "), terms) -> :topic
      true -> nil
    end
  end

  defp node_id(node), do: Map.get(node, :id) || Map.get(node, "id")

  defp graph_from_row(row) do
    %{
      title: row.graph_title,
      slug: row.graph_slug,
      tags: row.graph_tags || [],
      is_public: row.graph_is_public
    }
  end

  defp contains_pattern(query), do: "%" <> escape_like(query) <> "%"

  defp match_expression([]), do: dynamic(false)

  defp match_expression(terms) do
    Enum.reduce(terms, dynamic(true), fn term, acc ->
      if String.length(term) < 3 do
        pattern = Query.short_term_pattern(term)
        dynamic([document], ^acc and fragment("? ~* ?", document.search_text, ^pattern))
      else
        pattern = contains_pattern(term)

        dynamic(
          [document],
          ^acc and fragment("? ILIKE ? ESCAPE E'\\\\'", document.search_text, ^pattern)
        )
      end
    end)
  end

  defp escape_like(query) do
    query
    |> String.replace("\\", "\\\\")
    |> String.replace("%", "\\%")
    |> String.replace("_", "\\_")
  end
end
