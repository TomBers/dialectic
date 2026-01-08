defmodule Dialectic.Repo.Migrations.AddSlugToGraphs do
  use Ecto.Migration

  def change do
    alter table(:graphs) do
      add :slug, :string
    end

    create unique_index(:graphs, [:slug])
  end
end
