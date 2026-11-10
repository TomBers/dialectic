defmodule Dialectic.Repo.Migrations.AddMcpGridActions do
  use Ecto.Migration

  def change do
    create table(:mcp_grid_actions) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :request_id, :uuid, null: false
      add :graph_title, references(:graphs, column: :title, type: :string, on_delete: :nilify_all)
      add :parent_node_id, :string, null: false
      add :action, :string, null: false
      add :node_id, :string, null: false
      add :job_id, :bigint, null: false
      timestamps(type: :utc_datetime)
    end

    create unique_index(:mcp_grid_actions, [:user_id, :request_id])
  end
end
