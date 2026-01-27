defmodule Dialectic.Repo.Migrations.AddLinkedNodeToHighlights do
  use Ecto.Migration

  def change do
    alter table(:highlights) do
      add :linked_node_id, :string
      add :link_type, :string
    end

    create index(:highlights, [:linked_node_id])
    create index(:highlights, [:mudg_id, :linked_node_id])
  end
end
