defmodule Dialectic.Learning do
  import Ecto.Query

  alias Dialectic.Accounts.{Graph, GraphShare, Note, User}
  alias Dialectic.Follows.Follow
  alias Dialectic.Highlights.Highlight
  alias Dialectic.Learning.{Collection, CollectionGrid, Workspace}
  alias Dialectic.Repo

  def initialize_topics(%User{} = user) do
    Repo.transact(fn ->
      lock_folders(user)
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

        existing =
          Repo.all(
            from c in Collection,
              where: c.user_id == ^user.id and is_nil(c.parent_id),
              order_by: c.id
          )

        Enum.each(topics, fn {name, titles} ->
          collection =
            Enum.find(existing, &(topic_key(&1.name) == name)) ||
              Repo.insert!(%Collection{user_id: user.id, name: topic_name(name), origin: :tags})

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

  def create_collection(%User{} = user, attrs, parent_id \\ nil) do
    Repo.transact(fn ->
      lock_folders(user)

      with {:ok, parent} <- folder_parent(user, parent_id) do
        %Collection{user_id: user.id, parent_id: parent && parent.id}
        |> change_collection(attrs)
        |> Repo.insert()
      end
    end)
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
    Repo.transact(fn ->
      lock_folders(user)

      case get_collection(user, id) do
        nil -> {:error, :not_found}
        collection -> collection |> change_collection(attrs) |> Repo.update()
      end
    end)
  end

  def delete_collection(user, id) do
    Repo.transact(fn ->
      lock_folders(user)

      case get_collection(user, id) do
        nil -> {:error, :not_found}
        collection -> Repo.delete(collection)
      end
    end)
  end

  def move_collection(user, id, parent_id) do
    Repo.transact(fn ->
      lock_folders(user)

      with %Collection{origin: :manual} = collection <- get_collection(user, id),
           {:ok, parent} <- folder_parent(user, parent_id) do
        if parent && parent.id in descendant_ids(user, collection.id) do
          {:error, :cycle}
        else
          collection
          |> change_collection()
          |> Ecto.Changeset.put_change(:parent_id, parent && parent.id)
          |> Repo.update()
          |> case do
            {:ok, moved} ->
              moved_ids = descendant_ids(user, moved.id)

              titles =
                from m in CollectionGrid,
                  where: m.collection_id in ^moved_ids,
                  select: m.graph_title

              other_ids = collection_tree_ids(user, moved) -- moved_ids

              Repo.delete_all(
                from m in CollectionGrid,
                  where: m.collection_id in ^other_ids and m.graph_title in subquery(titles)
              )

              {:ok, moved}

            error ->
              error
          end
        end
      else
        _ -> {:error, :invalid_parent}
      end
    end)
  end

  defp folder_parent(_user, id) when id in [nil, "", "root"], do: {:ok, nil}

  defp folder_parent(user, id) do
    case get_collection(user, id) do
      %Collection{origin: :manual} = parent -> {:ok, parent}
      _ -> {:error, :invalid_parent}
    end
  end

  defp lock_folders(user) do
    Repo.one!(from u in User, where: u.id == ^user.id, lock: "FOR UPDATE")
  end

  defp descendant_ids(user, id) do
    rows =
      Repo.all(
        from c in Collection,
          where: c.user_id == ^user.id,
          select: %{id: c.id, parent_id: c.parent_id}
      )

    case Ecto.Type.cast(:id, id) do
      {:ok, id} ->
        if Enum.any?(rows, &(&1.id == id)),
          do: collect_descendants([id], Enum.group_by(rows, & &1.parent_id), MapSet.new()),
          else: []

      _ ->
        []
    end
  end

  defp collect_descendants([], _children, visited), do: MapSet.to_list(visited)

  defp collect_descendants([id | rest], children, visited) do
    if MapSet.member?(visited, id) do
      collect_descendants(rest, children, visited)
    else
      next = Enum.map(Map.get(children, id, []), & &1.id)
      collect_descendants(next ++ rest, children, MapSet.put(visited, id))
    end
  end

  defp with_collection_paths(collections) do
    by_id = Map.new(collections, &{&1.id, &1})

    Enum.map(collections, fn collection ->
      ancestors = collection_ancestors(collection.parent_id, by_id, [])

      Map.merge(collection, %{
        ancestor_ids: Enum.map(ancestors, & &1.id),
        depth: length(ancestors),
        path: Enum.map_join(ancestors ++ [collection], " / ", & &1.name)
      })
    end)
  end

  defp collection_ancestors(nil, _by_id, acc), do: acc

  defp collection_ancestors(id, by_id, acc) do
    case Map.get(by_id, id) do
      nil -> acc
      parent -> collection_ancestors(parent.parent_id, by_id, [parent | acc])
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
          origin: c.origin,
          parent_id: c.parent_id,
          grid_count: count(graph.title)
        }
    )
    |> with_collection_paths()
  end

  def add_grid(user, collection_id, graph_title) when is_binary(graph_title) do
    Repo.transact(fn ->
      lock_folders(user)

      with %Collection{} = collection <- get_collection(user, collection_id),
           true <- Repo.exists?(from g in accessible_grids(user), where: g.title == ^graph_title),
           {:ok, membership} <-
             %CollectionGrid{collection_id: collection.id, graph_title: graph_title}
             |> Ecto.Changeset.change()
             |> Ecto.Changeset.foreign_key_constraint(:collection_id)
             |> Ecto.Changeset.foreign_key_constraint(:graph_title)
             |> Repo.insert(
               on_conflict: :nothing,
               conflict_target: [:collection_id, :graph_title]
             ) do
        if collection.origin == :manual do
          other_ids = collection_tree_ids(user, collection) -- [collection.id]

          Repo.delete_all(
            from m in CollectionGrid,
              where: m.collection_id in ^other_ids and m.graph_title == ^graph_title
          )
        end

        {:ok, membership}
      else
        {:error, reason} -> {:error, reason}
        _ -> {:error, :not_found}
      end
    end)
  end

  defp collection_tree_ids(user, collection) do
    root = collection_root(user, collection)
    descendant_ids(user, root.id)
  end

  defp collection_root(_user, %Collection{parent_id: nil} = collection), do: collection

  defp collection_root(user, collection),
    do: collection_root(user, get_collection(user, collection.parent_id))

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
          ids =
            if Keyword.get(opts, :include_subfolders, false),
              do: descendant_ids(user, id),
              else: [id]

          titles =
            from m in CollectionGrid,
              join: c in Collection,
              on: c.id == m.collection_id,
              where: c.id in ^ids and c.user_id == ^user.id,
              select: m.graph_title

          from g in query, where: g.title in subquery(titles)
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

    term = String.trim(Keyword.get(opts, :search, "")) |> String.slice(0, 200)
    query = Dialectic.Learning.Search.filter(query, user, term)

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
    |> Dialectic.Learning.Search.add_matches(term)
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

    paths =
      Repo.all(
        from c in Collection,
          where: c.user_id == ^user.id,
          select: map(c, [:id, :name, :parent_id])
      )
      |> with_collection_paths()
      |> Map.new(&{&1.id, &1.path})

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
      |> Enum.map(&Map.put(&1, :path, Map.get(paths, &1.id, &1.name)))
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
