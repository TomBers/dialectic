defmodule Dialectic.Repo.Migrations.CreateQuestionPages do
  use Ecto.Migration

  def change do
    create table(:question_pages) do
      add :graph_title,
          references(:graphs, column: :title, type: :string, on_delete: :delete_all), null: false

      add :slug, :string, null: false
      add :draft, :map, null: false
      add :source, :map, null: false
      add :published, :map
      add :published_at, :utc_datetime
      add :first_published_at, :utc_datetime
      add :lock_version, :integer, null: false, default: 1
      add :editor_id, references(:users, on_delete: :nilify_all)
      timestamps(type: :utc_datetime)
    end

    create unique_index(:question_pages, [:graph_title])
    create unique_index(:question_pages, [:slug])
    create index(:question_pages, [:published_at])
  end
end
