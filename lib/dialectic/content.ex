defmodule Dialectic.Content do
  @moduledoc false

  import Ecto.Query

  alias Dialectic.Accounts.Graph
  alias Dialectic.Content.ContentDraft
  alias Dialectic.Repo
  alias DialecticWeb.Utils.NodeTitleHelper

  @default_limit 20

  def list_candidate_graphs(search_term \\ "", opts \\ []) do
    search = String.trim(search_term || "")
    limit = Keyword.get(opts, :limit, @default_limit)
    pattern = "%#{search}%"

    query =
      from g in Graph,
        where: g.is_published == true,
        where: g.is_public == true,
        where: g.is_deleted == false or is_nil(g.is_deleted),
        where: ^search == "" or ilike(g.title, ^pattern),
        left_join: author in assoc(g, :user),
        order_by: [desc: g.updated_at],
        limit: ^limit,
        select:
          {g, fragment("COALESCE(jsonb_array_length(?->'nodes'), 0)", g.data), author.username}

    Repo.all(query)
  end

  def get_public_graph(title) when is_binary(title) do
    Graph
    |> where([g], g.title == ^title)
    |> where([g], g.is_public == true)
    |> where([g], g.is_published == true)
    |> where([g], g.is_deleted == false or is_nil(g.is_deleted))
    |> Repo.one()
  end

  def list_graph_nodes(%Graph{} = graph, opts \\ []) do
    limit = Keyword.get(opts, :limit, 30)

    graph
    |> graph_nodes()
    |> Enum.reject(&hidden_node?/1)
    |> Enum.map(&node_summary/1)
    |> Enum.sort_by(fn node -> {node.sort_class, node.title} end)
    |> Enum.take(limit)
  end

  def create_draft(attrs, created_by) when is_map(attrs) do
    %ContentDraft{}
    |> ContentDraft.create_changeset(attrs, created_by)
    |> Repo.insert()
  end

  def update_draft(%ContentDraft{} = draft, attrs) when is_map(attrs) do
    draft
    |> ContentDraft.update_changeset(attrs)
    |> Repo.update()
  end

  def mark_draft_used(%ContentDraft{} = draft) do
    update_draft(draft, %{
      status: "used",
      published_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
  end

  def archive_draft(%ContentDraft{} = draft) do
    update_draft(draft, %{status: "archived"})
  end

  def get_draft!(id), do: Repo.get!(ContentDraft, id)

  def list_drafts(opts \\ []) do
    limit = Keyword.get(opts, :limit, @default_limit)
    graph_title = Keyword.get(opts, :graph_title)

    ContentDraft
    |> maybe_filter_graph(graph_title)
    |> preload([:graph, :created_by])
    |> order_by([d], desc: d.inserted_at)
    |> limit(^limit)
    |> Repo.all()
  end

  def graph_nodes(%Graph{data: %{"nodes" => nodes}}) when is_list(nodes), do: nodes
  def graph_nodes(_graph), do: []

  def node_summary(node) when is_map(node) do
    title = NodeTitleHelper.extract_node_title(node, max_length: 96)

    %{
      id: to_string(Map.get(node, "id") || Map.get(node, :id) || ""),
      title: title,
      class: Map.get(node, "class") || Map.get(node, :class) || "",
      excerpt: excerpt(Map.get(node, "content") || Map.get(node, :content) || "", 260),
      sort_class: node_sort_class(node)
    }
  end

  def excerpt(text, max_length \\ 220) do
    text
    |> to_string()
    |> strip_markdown()
    |> String.replace(~r/\s+/u, " ")
    |> String.trim()
    |> truncate(max_length)
  end

  defp maybe_filter_graph(query, nil), do: query
  defp maybe_filter_graph(query, ""), do: query

  defp maybe_filter_graph(query, graph_title),
    do: where(query, [d], d.graph_title == ^graph_title)

  defp hidden_node?(node) do
    Map.get(node, "deleted") == true or Map.get(node, :deleted) == true or
      Map.get(node, "compound") == true or Map.get(node, :compound) == true
  end

  defp node_sort_class(%{"class" => "origin"}), do: 0
  defp node_sort_class(%{class: "origin"}), do: 0
  defp node_sort_class(_node), do: 1

  defp strip_markdown(text) do
    text
    |> to_string()
    |> String.replace(~r/^\s*\#{1,6}\s*/m, "")
    |> String.replace(~r/[*_`>#\[\]()]/u, "")
  end

  defp truncate(text, max_length) do
    if String.length(text) > max_length do
      String.slice(text, 0, max_length) <> "..."
    else
      text
    end
  end
end
