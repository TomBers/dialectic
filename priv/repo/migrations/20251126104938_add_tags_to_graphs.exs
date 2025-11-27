defmodule Dialectic.Repo.Migrations.AddTagsToGraphs do
  use Ecto.Migration
  @disable_ddl_transaction true

  def up do
    execute "ALTER TABLE graphs ADD COLUMN IF NOT EXISTS tags text[] DEFAULT '{}'"
    create index(:graphs, [:tags], using: :gin, concurrently: true, if_not_exists: true)
  end

  def down do
    drop index(:graphs, [:tags], concurrently: true, if_exists: true)
    execute "ALTER TABLE graphs DROP COLUMN IF EXISTS tags"
  end
end
