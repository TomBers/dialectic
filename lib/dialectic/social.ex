defmodule Dialectic.Social do
  @moduledoc """
  The Social context. Manages follows between users and provides
  feed queries for displaying recent content from followed users.
  """

  import Ecto.Query, warn: false
  alias Dialectic.Repo
  alias Dialectic.Social.Follow
  alias Dialectic.Accounts.{User, Graph}

  @doc """
  Follows a user. Creates a follow relationship from follower to followed.

  Returns `{:ok, %Follow{}}` on success, or `{:error, %Ecto.Changeset{}}` if
  the follow already exists, the user tries to follow themselves, or either
  user ID is invalid.
  """
  def follow_user(%User{id: follower_id}, %User{id: followed_id}) do
    %Follow{}
    |> Follow.changeset(%{follower_id: follower_id, followed_id: followed_id})
    |> Repo.insert()
  end

  @doc """
  Unfollows a user. Deletes the follow relationship if it exists.

  Returns `{:ok, %Follow{}}` if the follow was deleted, or
  `{:error, :not_found}` if no such follow exists.
  """
  def unfollow_user(%User{id: follower_id}, %User{id: followed_id}) do
    case Repo.get_by(Follow, follower_id: follower_id, followed_id: followed_id) do
      nil -> {:error, :not_found}
      follow -> Repo.delete(follow)
    end
  end

  @doc """
  Returns true if `follower` is following `followed`.
  """
  def following?(%User{id: follower_id}, %User{id: followed_id}) do
    Repo.exists?(
      from(f in Follow,
        where: f.follower_id == ^follower_id and f.followed_id == ^followed_id
      )
    )
  end

  @doc """
  Returns the number of followers a user has.
  """
  def follower_count(%User{id: user_id}) do
    Repo.one(
      from(f in Follow,
        where: f.followed_id == ^user_id,
        select: count(f.id)
      )
    )
  end

  @doc """
  Returns the number of users a user is following.
  """
  def following_count(%User{id: user_id}) do
    Repo.one(
      from(f in Follow,
        where: f.follower_id == ^user_id,
        select: count(f.id)
      )
    )
  end

  @doc """
  Returns a list of users that the given user is following.
  """
  def list_following(%User{id: user_id}) do
    from(u in User,
      join: f in Follow,
      on: f.followed_id == u.id,
      where: f.follower_id == ^user_id,
      order_by: [desc: f.inserted_at]
    )
    |> Repo.all()
  end

  @doc """
  Returns a list of users that follow the given user.
  """
  def list_followers(%User{id: user_id}) do
    from(u in User,
      join: f in Follow,
      on: f.follower_id == u.id,
      where: f.followed_id == ^user_id,
      order_by: [desc: f.inserted_at]
    )
    |> Repo.all()
  end

  @doc """
  Returns the most recent public, published graphs from users that
  the given user follows. Each graph is preloaded with its user.

  ## Options

    * `:limit` - maximum number of graphs to return (default: 20)
  """
  def list_feed_graphs(%User{id: user_id}, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)

    from(g in Graph,
      join: f in Follow,
      on: f.followed_id == g.user_id,
      join: u in User,
      on: u.id == g.user_id,
      where: f.follower_id == ^user_id,
      where: g.is_published == true,
      where: g.is_public == true,
      where: g.is_deleted == false or is_nil(g.is_deleted),
      order_by: [desc: g.updated_at],
      limit: ^limit,
      preload: [user: u]
    )
    |> Repo.all()
  end
end
