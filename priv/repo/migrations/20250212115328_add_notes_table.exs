defmodule Dialectic.Repo.Migrations.AddNotesTable do
  use Ecto.Migration

  def change do
    create table(:notes) do
      add :node_id, :string
      add :is_noted, :boolean

      add :user_id, references(:users, on_delete: :delete_all), null: false

      add :graph_id, references(:graphs, column: :title, type: :string, on_delete: :delete_all),
        null: false

      timestamps(type: :utc_datetime)
    end

    create index(:notes, [:user_id, :graph_id, :node_id], unique: true)
  end
end
