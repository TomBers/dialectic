defmodule Dialectic.Repo.Migrations.CreateLearningWorkspaces do
  use Ecto.Migration

  def change do
    create table(:learning_workspaces, primary_key: false) do
      add :user_id, references(:users, on_delete: :delete_all), primary_key: true
      add :topics_initialized_at, :utc_datetime
    end
  end
end
