defmodule Dialectic.Repo.Migrations.CreateGridActivityLogs do
  use Ecto.Migration

  def change do
    create table(:grid_activity_logs) do
      add :graph_title,
          references(:graphs, column: :title, type: :string, on_delete: :delete_all),
          null: false

      add :user_id, references(:users, on_delete: :nilify_all)
      add :actor_name, :string, null: false
      add :action, :string, null: false
      add :message, :text, null: false
      add :node_id, :string

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:grid_activity_logs, [:graph_title, :inserted_at])
    create index(:grid_activity_logs, [:user_id])
  end
end
