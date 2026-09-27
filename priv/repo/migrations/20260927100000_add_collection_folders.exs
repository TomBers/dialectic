defmodule Dialectic.Repo.Migrations.AddCollectionFolders do
  use Ecto.Migration

  def up do
    alter table(:learning_collections) do
      add :parent_id, references(:learning_collections, on_delete: :delete_all)
    end

    create index(:learning_collections, [:parent_id])

    create constraint(:learning_collections, :learning_collections_parent_check,
             check: "parent_id IS NULL OR (parent_id <> id AND origin = 'manual')"
           )

    drop index(:learning_collections, [:user_id, "lower(name)"],
           name: :learning_collections_user_name_index
         )

    create unique_index(
             :learning_collections,
             [:user_id, "COALESCE(parent_id, 0)", "lower(name)"],
             name: :learning_collections_user_name_index
           )
  end

  def down do
    drop index(:learning_collections, [:user_id, "COALESCE(parent_id, 0)", "lower(name)"],
           name: :learning_collections_user_name_index
         )

    drop constraint(:learning_collections, :learning_collections_parent_check)
    drop index(:learning_collections, [:parent_id])

    alter table(:learning_collections) do
      remove :parent_id
    end

    create unique_index(:learning_collections, [:user_id, "lower(name)"],
             name: :learning_collections_user_name_index
           )
  end
end
