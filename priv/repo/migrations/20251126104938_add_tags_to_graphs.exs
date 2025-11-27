defmodule Dialectic.Repo.Migrations.AddTagsToGraphs do
  use Ecto.Migration
  @disable_ddl_transaction true

  def up do
    execute "ALTER TABLE graphs ADD COLUMN IF NOT EXISTS tags text[] DEFAULT '{}'"
    create_if_not_exists index(:graphs, [:tags], using: :gin, concurrently: true)
  end

  def down do
    drop_if_exists index(:graphs, [:tags], concurrently: true)
    execute "ALTER TABLE graphs DROP COLUMN IF EXISTS tags"
  end
end
