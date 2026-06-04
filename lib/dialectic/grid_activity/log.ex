defmodule Dialectic.GridActivity.Log do
  use Ecto.Schema
  import Ecto.Changeset

  alias Dialectic.Accounts.{Graph, User}

  schema "grid_activity_logs" do
    belongs_to :graph, Graph,
      foreign_key: :graph_title,
      references: :title,
      type: :string

    belongs_to :user, User

    field :actor_name, :string
    field :action, :string
    field :message, :string
    field :node_id, :string

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def changeset(log, attrs) do
    log
    |> cast(attrs, [:graph_title, :user_id, :actor_name, :action, :message, :node_id])
    |> validate_required([:graph_title, :actor_name, :action, :message])
    |> validate_length(:actor_name, min: 1, max: 160)
    |> validate_length(:action, min: 1, max: 80)
    |> validate_length(:message, min: 1, max: 500)
    |> foreign_key_constraint(:graph_title)
    |> foreign_key_constraint(:user_id)
  end
end
