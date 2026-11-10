defmodule Dialectic.Repo.Migrations.AddMcpContentReceipts do
  use Ecto.Migration

  def change do
    create table(:mcp_grid_snapshots) do
      add :graph_title,
          references(:graphs, column: :title, type: :string, on_delete: :delete_all), null: false

      add :revision, :bigint, null: false
      add :data, :map, null: false
      timestamps(type: :utc_datetime)
    end

    create unique_index(:mcp_grid_snapshots, [:graph_title, :revision])

    alter table(:mcp_grid_actions) do
      add :completed_revision, :bigint
    end

    alter table(:mcp_explorations) do
      add :completed_revision, :bigint
    end
  end
end
