defmodule Dialectic.Accounts.Note do
  use Ecto.Schema
  import Ecto.Changeset

  schema "notes" do
    field :node_id, :string
    field :is_noted, :boolean

    belongs_to :user, Dialectic.Accounts.User
    belongs_to :graph, Dialectic.Accounts.Graph, references: :title, type: :string

    timestamps(type: :utc_datetime)
  end

  def changeset(note, attrs) do
    note
    |> cast(attrs, [:user_id, :graph_id, :node_id, :is_noted])
    |> validate_required([:user_id, :graph_id, :node_id])
    # Enforce that a user can only note a post once.
    |> unique_constraint([:user_id, :graph_id, :node_id],
      name: :notes_graph_id_node_id_index
    )
  end
end
