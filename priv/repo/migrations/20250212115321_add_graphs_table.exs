defmodule Dialectic.Repo.Migrations.AddGraphsTable do
  use Ecto.Migration

  def change do
    create table(:graphs, primary_key: false) do
      add :title, :string, primary_key: true
      add :data, :map
      add :is_public, :boolean
      add :is_published, :boolean
      add :is_deleted, :boolean
      add :user_id, references(:users, on_delete: :delete_all), null: true

      timestamps()
    end
  end
end
