defmodule Dialectic.Content do
  @moduledoc false

  import Ecto.Query

  alias Dialectic.Accounts.Graph
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
          {g,
           fragment(
             "COALESCE(CASE WHEN jsonb_typeof(?->'nodes') = 'array' THEN jsonb_array_length(?->'nodes') ELSE 0 END, 0)",
             g.data,
             g.data
           ), author.username}

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
