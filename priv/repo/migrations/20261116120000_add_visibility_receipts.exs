defmodule Dialectic.Repo.Migrations.AddVisibilityReceipts do
  use Ecto.Migration

  def change do
    alter table(:graphs) do
      add :visibility_version, :bigint, null: false, default: 0
    end

    alter table(:mcp_grid_actions) do
      add :result, :map
    end
  end
end
