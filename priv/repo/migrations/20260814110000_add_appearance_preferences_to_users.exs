defmodule Dialectic.Repo.Migrations.AddAppearancePreferencesToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :reading_density, :string, null: false, default: "comfortable"
      add :reading_font, :string, null: false, default: "sans"
      add :graph_view_mode, :string, null: false, default: "spaced"
      add :graph_direction, :string, null: false, default: "TB"
    end
  end
end
