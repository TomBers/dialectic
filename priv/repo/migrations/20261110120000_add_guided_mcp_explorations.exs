defmodule Dialectic.Repo.Migrations.AddGuidedMcpExplorations do
  use Ecto.Migration

  def change do
    create table(:mcp_explorations) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :request_id, :uuid, null: false

      add :graph_title,
          references(:graphs, column: :title, type: :string, on_delete: :delete_all), null: false

      add :stage, :string, null: false, default: "opening"
      add :steps, :map, null: false, default: %{}
      add :error, :string
      timestamps(type: :utc_datetime)
    end

    create unique_index(:mcp_explorations, [:user_id, :request_id])
  end
end
