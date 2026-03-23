defmodule Dialectic.Accounts.CuratedGrid do
  use Ecto.Schema
  import Ecto.Changeset

  schema "curated_grids" do
    belongs_to :graph, Dialectic.Accounts.Graph,
      references: :title,
      type: :string,
      foreign_key: :graph_title

    belongs_to :curator, Dialectic.Accounts.User

    field :section, :string, default: "curated"
    field :position, :integer, default: 0
    field :note, :string

    timestamps(type: :utc_datetime)
  end

  def changeset(curated_grid, attrs) do
    curated_grid
    |> cast(attrs, [:graph_title, :curator_id, :section, :position, :note])
    |> validate_required([:graph_title, :section])
    |> validate_inclusion(:section, ~w(curated recent featured))
    |> unique_constraint([:graph_title, :section])
    |> foreign_key_constraint(:graph_title)
    |> foreign_key_constraint(:curator_id)
  end
end
