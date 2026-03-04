defmodule Dialectic.Repo.Migrations.AddProfileFieldsToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :username, :citext
      add :bio, :string, size: 500
      add :gravatar_id, :string, size: 100
      add :theme, :string, default: "default"
    end

    create unique_index(:users, [:username])
  end
end
