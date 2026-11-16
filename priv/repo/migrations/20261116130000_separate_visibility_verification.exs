defmodule Dialectic.Repo.Migrations.SeparateVisibilityVerification do
  use Ecto.Migration

  def change do
    alter table(:mcp_grid_actions) do
      add :verification, :map, null: false, default: %{}
    end
  end
end
