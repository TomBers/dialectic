defmodule Dialectic.Repo.Migrations.CreateCuratedHighlights do
  use Ecto.Migration

  def change do
    create table(:curated_highlights) do
      add :highlight_id, references(:highlights, on_delete: :delete_all), null: false
      add :curator_id, references(:users, on_delete: :nilify_all)
      add :position, :integer, default: 0
      add :note, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:curated_highlights, [:highlight_id])
    create index(:curated_highlights, [:position])
    create index(:curated_highlights, [:curator_id])
  end
end
