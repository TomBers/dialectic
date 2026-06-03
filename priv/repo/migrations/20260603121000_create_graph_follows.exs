defmodule Dialectic.Repo.Migrations.CreateGraphFollows do
  use Ecto.Migration

  def change do
    create table(:graph_follows) do
      add :user_id, references(:users, on_delete: :delete_all), null: false

      add :graph_title,
          references(:graphs, column: :title, type: :string, on_delete: :delete_all),
          null: false

      add :frequency, :string, null: false, default: "weekly"
      add :last_notified_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:graph_follows, [:user_id, :graph_title])
    create index(:graph_follows, [:graph_title])
  end
end
