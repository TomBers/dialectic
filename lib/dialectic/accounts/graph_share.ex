defmodule Dialectic.Accounts.GraphShare do
  use Ecto.Schema
  import Ecto.Changeset

  schema "graph_shares" do
    field :email, :string
    field :permission, :string, default: "edit"

    belongs_to :graph, Dialectic.Accounts.Graph,
      foreign_key: :graph_title,
      references: :title,
      type: :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(graph_share, attrs) do
    graph_share
    |> cast(attrs, [:graph_title, :email, :permission])
    |> validate_required([:graph_title, :email, :permission])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> unique_constraint([:graph_title, :email])
  end
end
