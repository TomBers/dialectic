defmodule Dialectic.Repo.Migrations.CreateHighlights do
  use Ecto.Migration

  def change do
    create table(:highlights) do
      add :mudg_id, references(:graphs, column: :title, type: :string, on_delete: :delete_all),
        null: false

      add :node_id, :string, null: false
      add :text_source_type, :string, null: false
      add :text_source_id, :string
      add :selection_start, :integer, null: false
      add :selection_end, :integer, null: false
      add :selected_text_snapshot, :text, null: false
      add :note, :text
      add :created_by_user_id, references(:users, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:highlights, [:mudg_id])
    create index(:highlights, [:created_by_user_id])
    create index(:highlights, [:mudg_id, :node_id])
  end
end
