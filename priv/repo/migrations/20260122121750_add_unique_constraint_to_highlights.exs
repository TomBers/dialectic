defmodule Dialectic.Repo.Migrations.AddUniqueConstraintToHighlights do
  use Ecto.Migration

  def change do
    # This migration intentionally left empty.
    # Originally created a unique index on [:mudg_id, :node_id, :selection_start, :selection_end],
    # but this constraint is redundant because validate_no_overlap in the Highlight schema
    # prevents ANY overlapping highlights, not just exact duplicates.
    # The validate_no_overlap validation is more restrictive and sufficient for data integrity.
  end
end
