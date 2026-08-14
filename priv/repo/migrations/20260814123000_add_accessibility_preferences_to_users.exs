defmodule Dialectic.Repo.Migrations.AddAccessibilityPreferencesToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :reduce_motion, :boolean, null: false, default: false
      add :high_contrast, :boolean, null: false, default: false
    end
  end
end
