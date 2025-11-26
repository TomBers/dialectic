defmodule Dialectic.Repo.Migrations.AddTagsToGraphs do
  use Ecto.Migration

  def change do
    alter table(:graphs) do
      add :tags, {:array, :string}, default: []
    end

    create index(:graphs, [:tags], using: :gin)
  end
end
