defmodule Dialectic.Repo.Migrations.CreateCuratedGrids do
  use Ecto.Migration

  def change do
    create table(:curated_grids) do
      add :graph_title,
          references(:graphs, column: :title, type: :string, on_delete: :delete_all),
          null: false

      add :curator_id, references(:users, on_delete: :nilify_all)
      add :section, :string, null: false, default: "curated"
      add :position, :integer, default: 0
      add :note, :string

      timestamps(type: :utc_datetime)
    end

    create index(:curated_grids, [:section, :position])
    create unique_index(:curated_grids, [:graph_title, :section])

    # Add is_admin field to users
    alter table(:users) do
      add :is_admin, :boolean, default: false, null: false
    end
  end
end
