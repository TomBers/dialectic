defmodule Dialectic.Notifications.GraphEvent do
  use Ecto.Schema
  import Ecto.Changeset

  @event_types ~w(
    graph.created
    graph.updated
    graph.published
    graph.unpublished
    graph.made_public
    graph.made_private
    graph.locked
    graph.unlocked
    graph.deleted
    graph.restored
    graph.tags_updated
    graph.shared
    graph.unshared
    graph.followed
    graph.unfollowed
  )

  schema "graph_events" do
    field :event_type, :string
    field :summary, :string
    field :metadata, :map, default: %{}
    field :occurred_at, :utc_datetime

    belongs_to :actor_user, Dialectic.Accounts.User

    belongs_to :graph, Dialectic.Accounts.Graph,
      foreign_key: :graph_title,
      references: :title,
      type: :string

    timestamps(type: :utc_datetime)
  end

  def event_types, do: @event_types

  def changeset(graph_event, attrs) do
    graph_event
    |> cast(attrs, [:graph_title, :actor_user_id, :event_type, :summary, :metadata, :occurred_at])
    |> validate_required([:graph_title, :event_type, :metadata, :occurred_at])
    |> validate_inclusion(:event_type, @event_types)
    |> validate_length(:summary, max: 500)
    |> foreign_key_constraint(:graph_title)
    |> foreign_key_constraint(:actor_user_id)
  end
end
