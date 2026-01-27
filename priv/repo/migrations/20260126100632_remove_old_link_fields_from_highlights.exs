defmodule Dialectic.Repo.Migrations.RemoveOldLinkFieldsFromHighlights do
  use Ecto.Migration

  def change do
    # Drop indexes first
    drop_if_exists index(:highlights, [:linked_node_id])
    drop_if_exists index(:highlights, [:mudg_id, :linked_node_id])

    # Remove old link fields
    alter table(:highlights) do
      remove :linked_node_id
      remove :link_type
    end
  end
end
