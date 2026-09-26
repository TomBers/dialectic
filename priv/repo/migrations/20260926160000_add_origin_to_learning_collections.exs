defmodule Dialectic.Repo.Migrations.AddOriginToLearningCollections do
  use Ecto.Migration

  def up do
    alter table(:learning_collections) do
      add :origin, :string, null: false, default: "manual"
    end

    create constraint(:learning_collections, :learning_collections_origin_check,
             check: "origin IN ('manual', 'tags')"
           )

    flush()

    # Starter collections and the initialization marker were written in one transaction.
    execute """
    UPDATE learning_collections AS collection
    SET origin = 'tags'
    FROM learning_workspaces AS workspace
    WHERE collection.user_id = workspace.user_id
      AND workspace.topics_initialized_at IS NOT NULL
      AND collection.inserted_at <= workspace.topics_initialized_at
      AND collection.xmin = workspace.xmin
    """
  end

  def down do
    drop constraint(:learning_collections, :learning_collections_origin_check)

    alter table(:learning_collections) do
      remove :origin
    end
  end
end
