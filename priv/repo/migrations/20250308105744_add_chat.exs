defmodule Dialectic.Repo.Migrations.AddChat do
  use Ecto.Migration

  def change do
    create table(:chats) do
      add :message, :text, null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false

      add :graph_title,
          references(:graphs, column: :title, type: :string, on_delete: :delete_all),
          null: false

      timestamps(type: :utc_datetime)
    end

    create index(:chats, [:graph_title])
    create index(:chats, [:user_id])
  end
end
