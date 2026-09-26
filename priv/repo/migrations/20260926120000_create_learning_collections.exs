defmodule Dialectic.Repo.Migrations.CreateLearningCollections do
  use Ecto.Migration

  def change do
    create table(:learning_collections) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :description, :text
      timestamps(type: :utc_datetime)
    end

    create unique_index(:learning_collections, [:user_id, "lower(name)"],
             name: :learning_collections_user_name_index
           )

    create table(:learning_collection_grids) do
      add :collection_id, references(:learning_collections, on_delete: :delete_all), null: false

      add :graph_title,
          references(:graphs, column: :title, type: :string, on_delete: :delete_all),
          null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:learning_collection_grids, [:collection_id, :graph_title])
    create index(:learning_collection_grids, [:graph_title])
  end
end
