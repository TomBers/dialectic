defmodule Dialectic.Repo.Migrations.AddProfileFieldsToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :username, :citext
      add :display_name, :string, size: 100
      add :bio, :string, size: 500
      add :avatar_type, :string, default: "default"
      add :theme, :string, default: "default"
      add :website_url, :string, size: 255
      add :twitter_handle, :string, size: 100
      add :linkedin_url, :string, size: 255
    end

    create unique_index(:users, [:username])
  end
end
