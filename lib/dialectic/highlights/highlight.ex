defmodule Dialectic.Highlights.Highlight do
  use Ecto.Schema
  import Ecto.Changeset
  alias Dialectic.Repo
  import Ecto.Query

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
             :linked_node_id,
             :link_type,
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
    field :linked_node_id, :string
    field :link_type, :string

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
      :linked_node_id,
      :link_type,
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
    |> validate_no_overlap()
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

  # WARNING: Performance implications
  # This validation performs a database query during changeset validation, which can cause
  # performance issues when validating multiple highlights in batch (N+1 query problem).
  # Consider moving this validation to the context layer (Highlights module) for better
  # control over batch operations, or implement database-level constraints/triggers.
  defp validate_no_overlap(changeset) do
    mudg_id = get_field(changeset, :mudg_id)
    node_id = get_field(changeset, :node_id)
    new_start = get_field(changeset, :selection_start)
    new_end = get_field(changeset, :selection_end)
    highlight_id = changeset.data.id

    # Only check if we have the required fields
    if mudg_id && node_id && new_start && new_end do
      # Check for overlapping highlights
      # Two ranges overlap if: start1 < end2 AND start2 < end1
      query =
        from h in __MODULE__,
          where: h.mudg_id == ^mudg_id,
          where: h.node_id == ^node_id,
          where: h.selection_start < ^new_end,
          where: h.selection_end > ^new_start

      # Exclude the current highlight if we're updating
      query =
        if highlight_id do
          from h in query, where: h.id != ^highlight_id
        else
          query
        end

      case Repo.one(query) do
        nil ->
          changeset

        _existing ->
          add_error(
            changeset,
            :selection_start,
            "A highlight already exists that overlaps with this text selection"
          )
      end
    else
      changeset
    end
  end
end
