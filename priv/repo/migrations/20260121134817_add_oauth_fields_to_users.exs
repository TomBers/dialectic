defmodule Dialectic.Repo.Migrations.AddOauthFieldsToUsers do
  use Ecto.Migration

  def up do
    alter table(:users) do
      add :provider, :string
      add :provider_id, :string
      add :provider_token, :binary
      add :provider_refresh_token, :binary
    end

    create unique_index(:users, [:provider, :provider_id])

    # Make hashed_password nullable for OAuth users
    execute "ALTER TABLE users ALTER COLUMN hashed_password DROP NOT NULL"
  end

  def down do
    # Before making hashed_password NOT NULL again, we need to handle OAuth users
    # Set a placeholder hashed password for OAuth users (who have NULL passwords)
    # This prevents the constraint from failing
    execute """
    UPDATE users
    SET hashed_password = '$2b$12$placeholder_hash_for_oauth_users_only'
    WHERE hashed_password IS NULL AND provider IS NOT NULL
    """

    execute "ALTER TABLE users ALTER COLUMN hashed_password SET NOT NULL"

    drop unique_index(:users, [:provider, :provider_id])

    alter table(:users) do
      remove :provider_refresh_token
      remove :provider_token
      remove :provider_id
      remove :provider
    end
  end
end
