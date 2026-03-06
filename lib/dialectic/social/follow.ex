defmodule Dialectic.Social.Follow do
  use Ecto.Schema
  import Ecto.Changeset

  schema "follows" do
    belongs_to :follower, Dialectic.Accounts.User
    belongs_to :followed, Dialectic.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(follow, attrs) do
    follow
    |> cast(attrs, [:follower_id, :followed_id])
    |> validate_required([:follower_id, :followed_id])
    |> unique_constraint([:follower_id, :followed_id])
    |> check_constraint(:follower_id,
      name: :cannot_follow_self,
      message: "you cannot follow yourself"
    )
    |> foreign_key_constraint(:follower_id)
    |> foreign_key_constraint(:followed_id)
  end
end
