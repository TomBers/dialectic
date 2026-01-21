defmodule Dialectic.Repo.Migrations.AddOauthFieldsToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :provider, :string
      add :provider_id, :string
      add :provider_token, :text
      add :provider_refresh_token, :text
    end

    create unique_index(:users, [:provider, :provider_id])

    # Make hashed_password nullable for OAuth users
    execute "ALTER TABLE users ALTER COLUMN hashed_password DROP NOT NULL",
            "ALTER TABLE users ALTER COLUMN hashed_password SET NOT NULL"
  end
end
