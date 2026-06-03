defmodule Dialectic.Notifications.GraphFollow do
  use Ecto.Schema
  import Ecto.Changeset

  @frequencies ~w(instant daily weekly never)

  schema "graph_follows" do
    field :frequency, :string, default: "weekly"
    field :last_notified_at, :utc_datetime

    belongs_to :user, Dialectic.Accounts.User

    belongs_to :graph, Dialectic.Accounts.Graph,
      foreign_key: :graph_title,
      references: :title,
      type: :string

    timestamps(type: :utc_datetime)
  end

  def frequencies, do: @frequencies

  def changeset(graph_follow, attrs) do
    graph_follow
    |> cast(attrs, [:user_id, :graph_title, :frequency, :last_notified_at])
    |> validate_required([:user_id, :graph_title, :frequency])
    |> validate_inclusion(:frequency, @frequencies)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:graph_title)
    |> unique_constraint([:user_id, :graph_title])
  end
end
