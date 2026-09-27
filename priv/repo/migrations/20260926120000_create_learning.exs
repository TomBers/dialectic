defmodule Dialectic.Repo.Migrations.CreateLearning do
  use Ecto.Migration

  def change do
    create table(:learning_collections) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :description, :text
      add :origin, :string, null: false, default: "manual"
      timestamps(type: :utc_datetime)
    end

    create constraint(:learning_collections, :learning_collections_origin_check,
             check: "origin IN ('manual', 'tags')"
           )

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

    create table(:learning_workspaces, primary_key: false) do
      add :user_id, references(:users, on_delete: :delete_all), primary_key: true
      add :topics_initialized_at, :utc_datetime
    end
  end
end
