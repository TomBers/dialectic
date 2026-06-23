defmodule Dialectic.Follows.Follow do
  use Ecto.Schema
  import Ecto.Changeset

  alias Dialectic.Accounts.{Graph, User}

  @target_types ~w(graph user topic)

  schema "follows" do
    belongs_to :follower, User, foreign_key: :follower_user_id

    belongs_to :graph, Graph,
      foreign_key: :graph_title,
      references: :title,
      type: :string

    belongs_to :target_user, User, foreign_key: :target_user_id

    field :target_type, :string
    field :topic, :string
    field :last_seen_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  def changeset(follow, attrs) do
    follow
    |> cast(attrs, [
      :follower_user_id,
      :target_type,
      :graph_title,
      :target_user_id,
      :topic,
      :last_seen_at
    ])
    |> update_change(:topic, &normalize_topic/1)
    |> validate_required([:follower_user_id, :target_type])
    |> validate_inclusion(:target_type, @target_types)
    |> validate_length(:topic, min: 1, max: 80)
    |> foreign_key_constraint(:follower_user_id)
    |> foreign_key_constraint(:graph_title)
    |> foreign_key_constraint(:target_user_id)
    |> check_constraint(:target_type, name: :follows_target_type_check)
    |> check_constraint(:target_type, name: :follows_target_shape_check)
    |> check_constraint(:target_user_id, name: :follows_no_self_user_follow_check)
    |> unique_constraint(:graph_title, name: :follows_unique_graph_target)
    |> unique_constraint(:target_user_id, name: :follows_unique_user_target)
    |> unique_constraint(:topic, name: :follows_unique_topic_target)
  end

  def normalize_topic(topic) when is_binary(topic) do
    topic
    |> String.trim()
    |> String.downcase()
  end

  def normalize_topic(topic), do: topic
end
