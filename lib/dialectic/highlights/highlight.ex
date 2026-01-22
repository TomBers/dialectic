defmodule Dialectic.Highlights.Highlight do
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder,
           only: [
             :id,
             :mudg_id,
             :node_id,
             :text_source_type,
             :text_source_id,
             :selection_start,
             :selection_end,
             :selected_text_snapshot,
             :note,
             :created_by_user_id,
             :inserted_at,
             :updated_at
           ]}
  schema "highlights" do
    field :node_id, :string
    field :text_source_type, :string
    field :text_source_id, :string
    field :selection_start, :integer
    field :selection_end, :integer
    field :selected_text_snapshot, :string
    field :note, :string

    belongs_to :mudg, Dialectic.Accounts.Graph,
      foreign_key: :mudg_id,
      references: :title,
      type: :string

    belongs_to :creator, Dialectic.Accounts.User, foreign_key: :created_by_user_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(highlight, attrs) do
    highlight
    |> cast(attrs, [
      :mudg_id,
      :node_id,
      :text_source_type,
      :text_source_id,
      :selection_start,
      :selection_end,
      :selected_text_snapshot,
      :note,
      :created_by_user_id
    ])
    |> validate_required([
      :mudg_id,
      :node_id,
      :text_source_type,
      :selection_start,
      :selection_end,
      :selected_text_snapshot,
      :created_by_user_id
    ])
    |> validate_number(:selection_start, greater_than_or_equal_to: 0)
    |> validate_number(:selection_end, greater_than_or_equal_to: 0)
    |> validate_range_order()
    |> unique_constraint([:mudg_id, :node_id, :selection_start, :selection_end],
      name: :highlights_unique_span,
      message: "A highlight already exists for this text selection"
    )
  end

  defp validate_range_order(changeset) do
    start = get_field(changeset, :selection_start)
    finish = get_field(changeset, :selection_end)

    if start && finish && finish <= start do
      add_error(changeset, :selection_end, "must be greater than selection_start")
    else
      changeset
    end
  end
end
