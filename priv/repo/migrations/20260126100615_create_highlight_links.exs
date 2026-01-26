defmodule Dialectic.Repo.Migrations.CreateHighlightLinks do
  use Ecto.Migration

  def change do
    create table(:highlight_links) do
      add :highlight_id, references(:highlights, on_delete: :delete_all), null: false
      add :node_id, :string, null: false
      add :link_type, :string, null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    # Index for querying all links for a highlight
    create index(:highlight_links, [:highlight_id])

    # Index for finding all highlights linked to a node
    create index(:highlight_links, [:node_id])

    # Unique constraint: a highlight cannot link to the same node twice
    create unique_index(:highlight_links, [:highlight_id, :node_id])
  end
end
