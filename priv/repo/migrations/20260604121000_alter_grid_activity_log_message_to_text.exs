defmodule Dialectic.Repo.Migrations.AlterGridActivityLogMessageToText do
  use Ecto.Migration

  def change do
    alter table(:grid_activity_logs) do
      modify :message, :text, null: false
    end
  end
end
