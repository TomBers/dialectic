defmodule Dialectic.Follows do
  import Ecto.Query

  alias Dialectic.Accounts.{Graph, User}
  alias Dialectic.DbActions.Sharing
  alias Dialectic.Follows.Follow
  alias Dialectic.GridActivity.Log
  alias Dialectic.Repo

  @default_feed_limit 50

  def follow_graph(nil, %Graph{}), do: {:error, :unauthenticated}

  def follow_graph(%User{} = user, %Graph{} = graph) do
    if Sharing.can_access?(user, graph) and graph.is_deleted != true do
      insert_follow(%{
        follower_user_id: user.id,
        target_type: "graph",
        graph_title: graph.title
      })
    else
      {:error, :unauthorized}
    end
  end

  def unfollow_graph(nil, %Graph{}), do: {:error, :unauthenticated}

  def unfollow_graph(%User{} = user, %Graph{} = graph) do
    delete_follow(user.id, graph: graph.title)
  end

  def following_graph?(nil, %Graph{}), do: false

  def following_graph?(%User{} = user, %Graph{} = graph) do
    exists_follow?(user.id, graph: graph.title)
  end

  def follow_user(nil, %User{}), do: {:error, :unauthenticated}
  def follow_user(%User{id: same_id}, %User{id: same_id}), do: {:error, :self_follow}

  def follow_user(%User{} = follower, %User{} = target_user) do
    insert_follow(%{
      follower_user_id: follower.id,
      target_type: "user",
      target_user_id: target_user.id
    })
  end

  def unfollow_user(nil, %User{}), do: {:error, :unauthenticated}

  def unfollow_user(%User{} = follower, %User{} = target_user) do
    delete_follow(follower.id, user: target_user.id)
  end

  def following_user?(nil, %User{}), do: false

  def following_user?(%User{} = follower, %User{} = target_user) do
    exists_follow?(follower.id, user: target_user.id)
  end

  def follow_topic(%User{} = user, topic) when is_binary(topic) do
    topic = Follow.normalize_topic(topic)

    insert_follow(%{
      follower_user_id: user.id,
      target_type: "topic",
      topic: topic
    })
  end

  def unfollow_topic(%User{} = user, topic) when is_binary(topic) do
    delete_follow(user.id, topic: Follow.normalize_topic(topic))
  end

  def following_topic?(%User{} = user, topic) when is_binary(topic) do
    exists_follow?(user.id, topic: Follow.normalize_topic(topic))
  end

  def list_user_follows(%User{} = user) do
    Follow
    |> where([f], f.follower_user_id == ^user.id)
    |> order_by([f], asc: f.target_type, asc: f.topic, asc: f.inserted_at)
    |> preload([:graph, :target_user])
    |> Repo.all()
  end

  def list_user_follows(nil), do: []

  def list_activity_feed(user, opts \\ [])

  def list_activity_feed(%User{} = user, opts) do
    limit = Keyword.get(opts, :limit, @default_feed_limit)

    graph_titles = followed_graph_titles(user)
    user_ids = followed_user_ids(user)
    topics = followed_topics(user)

    Log
    |> join(:inner, [log], graph in Graph, on: graph.title == log.graph_title)
    |> join(:left, [log, graph], actor in User, on: actor.id == log.actor_user_id)
    |> where([_log, graph, _actor], graph.is_deleted != true)
    |> where(
      [log, graph, _actor],
      graph.user_id == ^user.id or
        (graph.is_public == true and graph.is_published == true and
           (log.graph_title in ^graph_titles or graph.user_id in ^user_ids or
              fragment("?::text[] && ?::text[]", graph.tags, ^topics)))
    )
    |> order_by([log, _graph, _actor], desc: log.inserted_at, desc: log.id)
    |> limit(^limit)
    |> preload([_log, graph, actor], graph: graph, actor: actor)
    |> Repo.all()
  end

  def list_activity_feed(nil, _opts), do: []

  def mark_seen(%User{} = user) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    from(f in Follow, where: f.follower_user_id == ^user.id)
    |> Repo.update_all(set: [last_seen_at: now, updated_at: now])
  end

  def mark_seen(nil), do: {:error, :unauthenticated}

  defp insert_follow(attrs) do
    %Follow{}
    |> Follow.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, follow} -> {:ok, follow}
      {:error, changeset} -> {:error, changeset}
    end
  end

  defp followed_graph_titles(%User{} = user) do
    Follow
    |> where([f], f.follower_user_id == ^user.id and f.target_type == "graph")
    |> select([f], f.graph_title)
    |> Repo.all()
  end

  defp followed_user_ids(%User{} = user) do
    Follow
    |> where([f], f.follower_user_id == ^user.id and f.target_type == "user")
    |> select([f], f.target_user_id)
    |> Repo.all()
  end

  defp followed_topics(%User{} = user) do
    Follow
    |> where([f], f.follower_user_id == ^user.id and f.target_type == "topic")
    |> select([f], f.topic)
    |> Repo.all()
  end

  defp exists_follow?(user_id, graph: graph_title) do
    Repo.exists?(
      from f in Follow,
        where:
          f.follower_user_id == ^user_id and f.target_type == "graph" and
            f.graph_title == ^graph_title
    )
  end

  defp exists_follow?(user_id, user: target_user_id) do
    Repo.exists?(
      from f in Follow,
        where:
          f.follower_user_id == ^user_id and f.target_type == "user" and
            f.target_user_id == ^target_user_id
    )
  end

  defp exists_follow?(user_id, topic: topic) do
    Repo.exists?(
      from f in Follow,
        where: f.follower_user_id == ^user_id and f.target_type == "topic" and f.topic == ^topic
    )
  end

  defp delete_follow(user_id, graph: graph_title) do
    {count, _} =
      from(f in Follow,
        where:
          f.follower_user_id == ^user_id and f.target_type == "graph" and
            f.graph_title == ^graph_title
      )
      |> Repo.delete_all()

    {:ok, count}
  end

  defp delete_follow(user_id, user: target_user_id) do
    {count, _} =
      from(f in Follow,
        where:
          f.follower_user_id == ^user_id and f.target_type == "user" and
            f.target_user_id == ^target_user_id
      )
      |> Repo.delete_all()

    {:ok, count}
  end

  defp delete_follow(user_id, topic: topic) do
    {count, _} =
      from(f in Follow,
        where: f.follower_user_id == ^user_id and f.target_type == "topic" and f.topic == ^topic
      )
      |> Repo.delete_all()

    {:ok, count}
  end
end
