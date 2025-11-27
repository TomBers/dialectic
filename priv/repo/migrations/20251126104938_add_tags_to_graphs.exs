defmodule Dialectic.Repo.Migrations.AddTagsToGraphs do
  use Ecto.Migration
  @disable_ddl_transaction true

  def change do
    alter table(:graphs) do
      add :tags, {:array, :string}, default: []
    end

    create index(:graphs, [:tags], using: :gin, concurrently: true)
  end
end
