defmodule Dialectic.Repo.Migrations.AddUniqueConstraintToHighlights do
  use Ecto.Migration

  def change do
    create unique_index(:highlights, [:mudg_id, :node_id, :selection_start, :selection_end],
             name: :highlights_unique_span
           )
  end
end
