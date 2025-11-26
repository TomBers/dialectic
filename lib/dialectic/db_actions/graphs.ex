defmodule Dialectic.DbActions.Graphs do
  alias Dialectic.Repo
  alias Dialectic.Accounts.Graph
  alias Dialectic.Graph.Vertex

  import Ecto.Query

  @doc """
  Creates a new graph with the given title.
  """
  def create_new_graph(title, user \\ nil) do
    data = %{
      "nodes" => [%Vertex{id: "1", content: "## " <> title, class: "origin"}],
      "edges" => []
    }

    token = generate_share_token()

    %Graph{}
    |> Graph.changeset(%{
      title: title,
      user_id: user && user.id,
      data: data,
      is_public: true,
      is_locked: false,
      is_deleted: false,
      is_published: true,
      share_token: token
    })
    |> Repo.insert()
  end

  def list_graphs do
    # query =
    #   from p in Graph,
    #     select: p.title

    Repo.all(Graph)
  end

  def all_graphs_with_notes(search_term \\ "") do
    search_pattern = "%#{String.trim(search_term)}%"

    query =
      from g in Dialectic.Accounts.Graph,
        where: g.is_published == true,
        where: g.is_public == true,
        where: ilike(g.title, ^search_pattern),
        left_join: n in assoc(g, :notes),
        group_by: g.title,
        order_by: [desc: count(n.id), desc: g.inserted_at],
        select: {g, count(n.id)}

    Dialectic.Repo.all(query)
  end

  def list_seedlings(limit \\ 10) do
    query =
      from g in Graph,
        where: g.is_published == true,
        where: g.is_public == true,
        where: fragment("jsonb_array_length(?->'nodes') < ?", g.data, 5),
        order_by: [desc: g.inserted_at],
        limit: ^limit

    Repo.all(query)
  end

  def list_deep_dives(limit \\ 10) do
    query =
      from g in Graph,
        where: g.is_published == true,
        where: g.is_public == true,
        where: fragment("jsonb_array_length(?->'nodes') > ?", g.data, 20),
        order_by: [desc: g.updated_at],
        limit: ^limit

    Repo.all(query)
  end

  def list_popular_tags(limit \\ 10) do
    tags_query =
      from g in Graph,
        where: g.is_published == true,
        where: g.is_public == true,
        select: %{tag: fragment("unnest(?)", g.tags)}

    query =
      from t in subquery(tags_query),
        group_by: t.tag,
        order_by: [desc: count(t.tag)],
        limit: ^limit,
        select: {t.tag, count(t.tag)}

    Repo.all(query)
  end

  def list_graphs_by_tag(tag, limit \\ 20) do
    query =
      from g in Graph,
        where: g.is_published == true,
        where: g.is_public == true,
        where: ^tag in g.tags,
        order_by: [desc: g.updated_at],
        limit: ^limit

    Repo.all(query)
  end

  @doc """
  Retrieves a graph by its title.
  """
  def get_graph_by_title(title) do
    Repo.get_by(Graph, title: title)
  end

  @doc """
  Saves (updates) the graph data for the graph with the given title.
  Returns {:ok, graph} if successful or {:error, changeset} if not.
  If no graph is found, returns {:error, :not_found}.
  """
  def save_graph(title, data) do
    case get_graph_by_title(title) do
      nil ->
        {:error, :not_found}

      graph ->
        graph
        |> Graph.changeset(%{data: data})
        |> Repo.update()
    end
  end

  def update_tags(graph, tags) when is_list(tags) do
    graph
    |> Graph.changeset(%{tags: tags})
    |> Repo.update()
  end

  def toggle_graph_locked(graph) do
    graph
    |> Graph.changeset(%{is_locked: !graph.is_locked})
    |> Repo.update!()
  end

  def toggle_graph_public(graph) do
    {:ok, graph} = Dialectic.DbActions.Sharing.ensure_share_token(graph)

    updated_graph =
      graph
      |> Graph.changeset(%{is_public: !graph.is_public})
      |> Repo.update!()

    if updated_graph.is_public do
      Dialectic.Categorisation.AutoTagger.tag_graph(updated_graph)
    end

    updated_graph
  end

  @doc """
  Saves the graph only if the provided snapshot timestamp is newer than or equal to
  the current stored row's updated_at.

  Returns:
  - {:ok, :updated} if the row was updated
  - {:error, :stale} if the DB has a newer row (update skipped)
  - {:error, :invalid_timestamp} if ts can't be parsed
  - {:error, :not_found} if the graph doesn't exist
  """
  def save_graph_if_newer(title, data, iso_ts) when is_binary(iso_ts) do
    with {:ok, ts, _offset} <- DateTime.from_iso8601(iso_ts) do
      case get_graph_by_title(title) do
        nil ->
          {:error, :not_found}

        _graph ->
          {count, _} =
            from(g in Graph,
              where: g.title == ^title and (is_nil(g.updated_at) or g.updated_at <= ^ts)
            )
            |> Repo.update_all(set: [data: data, updated_at: DateTime.utc_now()])

          if count == 1 do
            {:ok, :updated}
          else
            {:error, :stale}
          end
      end
    else
      _ -> {:error, :invalid_timestamp}
    end
  end

  defp generate_share_token do
    :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)
  end
end
