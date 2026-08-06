defmodule Dialectic.Repo.Migrations.AddDataRevisionToGraphs do
  use Ecto.Migration

  def change do
    alter table(:graphs) do
      add :data_revision, :bigint, null: false, default: 0
    end
  end
end
