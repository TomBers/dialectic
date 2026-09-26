defmodule Dialectic.Learning do
  import Ecto.Query

  alias Dialectic.Accounts.{Graph, GraphShare, Note, User}
  alias Dialectic.Follows.Follow
  alias Dialectic.Highlights.Highlight
  alias Dialectic.Learning.{Collection, CollectionGrid, Workspace}
  alias Dialectic.Repo

  def initialize_topics(%User{} = user) do
    Repo.transact(fn ->
      Repo.insert!(%Workspace{user_id: user.id}, on_conflict: :nothing)
      workspace = Repo.one!(from w in Workspace, where: w.user_id == ^user.id, lock: "FOR UPDATE")

      if workspace.topics_initialized_at do
        {:ok, :already_initialized}
      else
        topics =
          Repo.all(from g in library_grids(user), select: %{title: g.title, tags: g.tags})
          |> Enum.flat_map(fn grid ->
            (grid.tags || [])
            |> Enum.map(&topic_key/1)
            |> Enum.reject(&(&1 == "" or String.length(&1) > 80))
            |> Enum.uniq()
            |> Enum.map(&{&1, grid.title})
          end)
          |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
          |> Enum.sort_by(fn {name, titles} -> {-length(titles), name} end)
          |> Enum.take(12)

        existing = Repo.all(from c in Collection, where: c.user_id == ^user.id, order_by: c.id)

        Enum.each(topics, fn {name, titles} ->
          collection =
            Enum.find(existing, &(topic_key(&1.name) == name)) ||
              Repo.insert!(%Collection{user_id: user.id, name: topic_name(name)})

          now = DateTime.utc_now() |> DateTime.truncate(:second)

          rows =
            Enum.map(
              titles,
              &%{collection_id: collection.id, graph_title: &1, inserted_at: now, updated_at: now}
            )

          Repo.insert_all(CollectionGrid, rows, on_conflict: :nothing)
        end)

        if topics != [] do
          workspace
          |> Ecto.Changeset.change(
            topics_initialized_at: DateTime.utc_now() |> DateTime.truncate(:second)
          )
          |> Repo.update!()
        end

        {:ok, :initialized}
      end
    end)
  end

  defp topic_key(tag) when is_binary(tag),
    do: tag |> String.trim() |> String.downcase() |> String.replace(~r/[\s_-]+/u, " ")

  defp topic_key(_tag), do: ""

  defp topic_name(name), do: String.replace(name, ~r/(^|\s)\p{Ll}/u, &String.upcase/1)

  def change_collection(collection \\ %Collection{}, attrs \\ %{}) do
    Collection.changeset(collection, attrs)
  end

  def create_collection(%User{} = user, attrs) do
    %Collection{user_id: user.id}
    |> change_collection(attrs)
    |> Repo.insert()
  end

  def get_collection(%User{} = user, id) do
    case Ecto.Type.cast(:id, id) do
      {:ok, id} when is_integer(id) and id > 0 and id <= 9_223_372_036_854_775_807 ->
        Repo.get_by(Collection, id: id, user_id: user.id)

      _ ->
        nil
    end
  end

  def get_collection(_user, _id), do: nil

  def update_collection(user, id, attrs) do
    case get_collection(user, id) do
      nil -> {:error, :not_found}
      collection -> collection |> change_collection(attrs) |> Repo.update()
    end
  end

  def delete_collection(user, id) do
    case get_collection(user, id) do
      nil -> {:error, :not_found}
      collection -> Repo.delete(collection)
    end
  end

  def list_collections(%User{} = user) do
    accessible_titles = from g in accessible_grids(user), select: g.title

    Repo.all(
      from c in Collection,
        left_join: membership in CollectionGrid,
        on: membership.collection_id == c.id,
        left_join: graph in subquery(accessible_titles),
        on: graph.title == membership.graph_title,
        where: c.user_id == ^user.id,
        group_by: c.id,
        order_by: [asc: fragment("lower(?)", c.name), asc: c.id],
        select: %{
          id: c.id,
          name: c.name,
          description: c.description,
          grid_count: count(graph.title)
        }
    )
  end

  def add_grid(user, collection_id, graph_title) when is_binary(graph_title) do
    with %Collection{} = collection <- get_collection(user, collection_id),
         true <- Repo.exists?(from g in accessible_grids(user), where: g.title == ^graph_title) do
      %CollectionGrid{collection_id: collection.id, graph_title: graph_title}
      |> Ecto.Changeset.change()
      |> Ecto.Changeset.foreign_key_constraint(:collection_id)
      |> Ecto.Changeset.foreign_key_constraint(:graph_title)
      |> Repo.insert(on_conflict: :nothing, conflict_target: [:collection_id, :graph_title])
    else
      _ -> {:error, :not_found}
    end
  end

  def remove_grid(user, collection_id, graph_title) when is_binary(graph_title) do
    case get_collection(user, collection_id) do
      nil ->
        {:error, :not_found}

      collection ->
        Repo.delete_all(
          from m in CollectionGrid,
            where: m.collection_id == ^collection.id and m.graph_title == ^graph_title
        )

        :ok
    end
  end

  def list_grids(%User{} = user, opts \\ []) do
    query = library_grids(user)

    query =
      case Keyword.get(opts, :saved_kind) do
        "bookmarks" ->
          titles =
            from n in Note,
              where: n.user_id == ^user.id and n.is_noted == true,
              select: n.graph_title

          from g in query, where: g.title in subquery(titles)

        "highlights" ->
          titles = from h in Highlight, where: h.created_by_user_id == ^user.id, select: h.mudg_id
          from g in query, where: g.title in subquery(titles)

        _ ->
          query
      end

    query =
      case Keyword.get(opts, :collection_id) do
        nil ->
          query

        id ->
          from g in query,
            join: m in CollectionGrid,
            on: m.graph_title == g.title and m.collection_id == ^id,
            join: c in Collection,
            on: c.id == m.collection_id and c.user_id == ^user.id
      end

    query =
      case Keyword.get(opts, :exclude_collection_id) do
        nil ->
          query

        id ->
          members =
            from m in CollectionGrid,
              join: c in Collection,
              on: c.id == m.collection_id,
              where: c.id == ^id and c.user_id == ^user.id,
              select: m.graph_title

          from g in query, where: g.title not in subquery(members)
      end

    query =
      case String.trim(Keyword.get(opts, :search, "")) do
        "" ->
          query

        term ->
          pattern = "%" <> String.replace(term, ~r/[\\%_]/, fn char -> "\\" <> char end) <> "%"

          from g in query,
            where:
              ilike(g.title, ^pattern) or
                ilike(fragment("array_to_string(?, ' ')", g.tags), ^pattern)
      end

    limit = opts |> Keyword.get(:limit, 25) |> max(1) |> min(100)
    offset = opts |> Keyword.get(:offset, 0) |> max(0)

    Repo.all(
      from g in query,
        order_by: [desc: g.updated_at, asc: g.title],
        limit: ^limit,
        offset: ^offset,
        select: map(g, [:title, :slug, :tags, :is_public, :updated_at, :user_id])
    )
    |> with_saved_items(user)
  end

  def remove_bookmark(%User{} = user, id) do
    case Repo.get_by(Note, id: saved_item_id(id), user_id: user.id, is_noted: true) do
      nil -> {:error, :not_found}
      note -> Dialectic.DbActions.Notes.remove_note(note.graph_title, note.node_id, user)
    end
  end

  def remove_highlight(%User{} = user, id) do
    case Repo.get_by(Highlight, id: saved_item_id(id), created_by_user_id: user.id) do
      nil -> {:error, :not_found}
      highlight -> Dialectic.Highlights.delete_highlight(highlight)
    end
  end

  defp saved_item_id(id) do
    case Ecto.Type.cast(:id, id) do
      {:ok, id} when is_integer(id) and id > 0 and id <= 9_223_372_036_854_775_807 -> id
      _ -> -1
    end
  end

  defp with_saved_items([], _user), do: []

  defp with_saved_items(grids, user) do
    titles = Enum.map(grids, & &1.title)

    bookmarks =
      Repo.all(
        from n in Note,
          where: n.user_id == ^user.id and n.is_noted == true and n.graph_title in ^titles,
          order_by: [desc: n.updated_at],
          preload: [:graph]
      )
      |> Enum.map(fn note ->
        %{
          id: note.id,
          graph_title: note.graph_title,
          node_id: note.node_id,
          title: saved_node_title(note.graph, note.node_id)
        }
      end)
      |> Enum.group_by(& &1.graph_title)

    highlights =
      Repo.all(
        from h in Highlight,
          where: h.created_by_user_id == ^user.id and h.mudg_id in ^titles,
          order_by: [desc: h.updated_at]
      )
      |> Enum.group_by(& &1.mudg_id)

    memberships =
      Repo.all(
        from m in CollectionGrid,
          join: c in Collection,
          on: c.id == m.collection_id,
          where: c.user_id == ^user.id and m.graph_title in ^titles,
          order_by: c.name,
          select: %{graph_title: m.graph_title, id: c.id, name: c.name}
      )
      |> Enum.group_by(& &1.graph_title)

    Enum.map(grids, fn grid ->
      Map.merge(grid, %{
        bookmarks: Map.get(bookmarks, grid.title, []),
        highlights: Map.get(highlights, grid.title, []),
        collections: Map.get(memberships, grid.title, [])
      })
    end)
  end

  defp saved_node_title(graph, node_id) do
    nodes = Map.get(graph.data || %{}, "nodes", [])
    node = Enum.find(nodes, &(Map.get(&1, "id") == node_id))

    if node,
      do: DialecticWeb.Utils.NodeTitleHelper.extract_node_title(node, max_length: 100),
      else: "Saved answer"
  end

  defp library_grids(user) do
    noted =
      from n in Note, where: n.user_id == ^user.id and n.is_noted == true, select: n.graph_title

    highlighted = from h in Highlight, where: h.created_by_user_id == ^user.id, select: h.mudg_id

    followed =
      from f in Follow,
        where: f.follower_user_id == ^user.id and f.target_type == "graph",
        select: f.graph_title

    shared = shared_titles(user)

    collected =
      from m in CollectionGrid,
        join: c in Collection,
        on: c.id == m.collection_id,
        where: c.user_id == ^user.id,
        select: m.graph_title

    from g in accessible_grids(user),
      where:
        g.user_id == ^user.id or g.title in subquery(noted) or
          g.title in subquery(highlighted) or g.title in subquery(followed) or
          g.title in subquery(shared) or g.title in subquery(collected)
  end

  defp accessible_grids(%User{} = user) do
    shared = shared_titles(user)

    from g in Graph,
      where: g.is_deleted == false or is_nil(g.is_deleted),
      where: g.user_id == ^user.id or g.is_public == true or g.title in subquery(shared)
  end

  defp shared_titles(user) do
    from s in GraphShare, where: s.email == ^user.email, select: s.graph_title
  end
end
