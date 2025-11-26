defmodule Dialectic.Repo.Migrations.AddIsLockedToGraphs do
  use Ecto.Migration

  def change do
    alter table(:graphs) do
      add :is_locked, :boolean, default: false, null: false
    end
  end
end
