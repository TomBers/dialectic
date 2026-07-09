defmodule Dialectic.Content do
  @moduledoc false

  import Ecto.Query

  alias Dialectic.Accounts.Graph
  alias Dialectic.Repo

  def list_public_graphs do
    query =
      from g in Graph,
        where: g.is_published == true,
        where: g.is_public == true,
        where: g.is_deleted == false or is_nil(g.is_deleted),
        order_by: [desc: g.updated_at],
        select:
          {g,
           fragment(
             "COALESCE(CASE WHEN jsonb_typeof(?->'nodes') = 'array' THEN jsonb_array_length(?->'nodes') ELSE 0 END, 0)",
             g.data,
             g.data
           )}

    Repo.all(query)
  end

  def get_public_graph_by_slug_or_title(identifier) when is_binary(identifier) do
    base_query = public_graph_query(Graph)

    Repo.one(from g in base_query, where: g.slug == ^identifier) ||
      Repo.one(from g in base_query, where: g.title == ^identifier)
  end

  def node_count(%Graph{} = graph) do
    graph
    |> graph_nodes()
    |> length()
  end

  def graph_nodes(%Graph{data: %{"nodes" => nodes}}) when is_list(nodes), do: nodes
  def graph_nodes(_graph), do: []

  defp public_graph_query(query) do
    query
    |> where([g], g.is_public == true)
    |> where([g], g.is_published == true)
    |> where([g], g.is_deleted == false or is_nil(g.is_deleted))
  end
end
