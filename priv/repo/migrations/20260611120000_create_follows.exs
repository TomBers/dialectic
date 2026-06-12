defmodule Dialectic.Repo.Migrations.CreateFollows do
  use Ecto.Migration

  def change do
    create table(:follows) do
      add :follower_user_id, references(:users, on_delete: :delete_all), null: false
      add :target_type, :string, null: false

      add :graph_title,
          references(:graphs, column: :title, type: :string, on_delete: :delete_all)

      add :target_user_id, references(:users, on_delete: :delete_all)
      add :topic, :string
      add :last_seen_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create constraint(:follows, :follows_target_type_check,
             check: "target_type IN ('graph', 'user', 'topic')"
           )

    create constraint(:follows, :follows_target_shape_check,
             check: """
             (
               target_type = 'graph'
               AND graph_title IS NOT NULL
               AND target_user_id IS NULL
               AND topic IS NULL
             ) OR (
               target_type = 'user'
               AND graph_title IS NULL
               AND target_user_id IS NOT NULL
               AND topic IS NULL
             ) OR (
               target_type = 'topic'
               AND graph_title IS NULL
               AND target_user_id IS NULL
               AND topic IS NOT NULL
             )
             """
           )

    create constraint(:follows, :follows_no_self_user_follow_check,
             check: "target_type != 'user' OR follower_user_id != target_user_id"
           )

    create index(:follows, [:follower_user_id, :target_type])
    create index(:follows, [:graph_title])
    create index(:follows, [:target_user_id])
    create index(:follows, [:topic])

    create unique_index(:follows, [:follower_user_id, :graph_title],
             where: "target_type = 'graph'",
             name: :follows_unique_graph_target
           )

    create unique_index(:follows, [:follower_user_id, :target_user_id],
             where: "target_type = 'user'",
             name: :follows_unique_user_target
           )

    create unique_index(:follows, [:follower_user_id, :topic],
             where: "target_type = 'topic'",
             name: :follows_unique_topic_target
           )
  end
end
