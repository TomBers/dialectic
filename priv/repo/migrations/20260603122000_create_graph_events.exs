defmodule Dialectic.Repo.Migrations.CreateGraphEvents do
  use Ecto.Migration

  def change do
    create table(:graph_events) do
      add :graph_title,
          references(:graphs, column: :title, type: :string, on_delete: :delete_all),
          null: false

      add :actor_user_id, references(:users, on_delete: :nilify_all)
      add :event_type, :string, null: false
      add :summary, :string
      add :metadata, :map, null: false, default: %{}
      add :occurred_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:graph_events, [:graph_title, :occurred_at])
    create index(:graph_events, [:actor_user_id])
    create index(:graph_events, [:event_type])
    create index(:graph_events, [:occurred_at])
  end
end
