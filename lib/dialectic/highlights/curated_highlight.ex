defmodule Dialectic.Highlights.CuratedHighlight do
  use Ecto.Schema
  import Ecto.Changeset

  schema "curated_highlights" do
    belongs_to :highlight, Dialectic.Highlights.Highlight
    belongs_to :curator, Dialectic.Accounts.User

    field :position, :integer, default: 0
    field :note, :string

    timestamps(type: :utc_datetime)
  end

  def changeset(curated_highlight, attrs) do
    curated_highlight
    |> cast(attrs, [:highlight_id, :curator_id, :position, :note])
    |> validate_required([:highlight_id])
    |> unique_constraint(:highlight_id)
    |> foreign_key_constraint(:highlight_id)
    |> foreign_key_constraint(:curator_id)
  end
end
