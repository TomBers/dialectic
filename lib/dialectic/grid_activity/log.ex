defmodule Dialectic.GridActivity.Log do
  use Ecto.Schema
  import Ecto.Changeset

  alias Dialectic.Accounts.{Graph, User}
  alias Dialectic.GridActivity.Actions

  schema "grid_activity_logs" do
    belongs_to :graph, Graph,
      foreign_key: :graph_title,
      references: :title,
      type: :string

    belongs_to :actor, User, foreign_key: :actor_user_id

    field :actor_name, :string
    field :action, :string
    field :node_id, :string
    field :metadata, :map, default: %{}

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def changeset(log, attrs) do
    log
    |> cast(attrs, [:graph_title, :actor_user_id, :actor_name, :action, :node_id, :metadata])
    |> validate_required([:graph_title, :actor_name, :action])
    |> validate_length(:actor_name, min: 1, max: 160)
    |> validate_length(:action, min: 1, max: 80)
    |> validate_inclusion(:action, Actions.valid_actions())
    |> validate_metadata()
    |> foreign_key_constraint(:graph_title)
    |> foreign_key_constraint(:actor_user_id)
  end

  defp validate_metadata(changeset) do
    case get_field(changeset, :metadata) do
      nil -> put_change(changeset, :metadata, %{})
      metadata when is_map(metadata) -> changeset
      _metadata -> add_error(changeset, :metadata, "must be a map")
    end
  end
end
