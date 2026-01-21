defmodule Dialectic.Repo.Migrations.AlterOauthTokenColumnsToBinary do
  use Ecto.Migration

  def up do
    # Clear existing OAuth tokens before changing column type
    # This is safe because tokens are short-lived and users can re-authenticate
    execute "UPDATE users SET provider_token = NULL, provider_refresh_token = NULL WHERE provider_token IS NOT NULL OR provider_refresh_token IS NOT NULL"

    # Now alter the columns from text to binary (bytea)
    execute "ALTER TABLE users ALTER COLUMN provider_token TYPE bytea USING NULL"
    execute "ALTER TABLE users ALTER COLUMN provider_refresh_token TYPE bytea USING NULL"
  end

  def down do
    # Clear binary data before converting back to text
    execute "UPDATE users SET provider_token = NULL, provider_refresh_token = NULL WHERE provider_token IS NOT NULL OR provider_refresh_token IS NOT NULL"

    # Revert back to text columns
    execute "ALTER TABLE users ALTER COLUMN provider_token TYPE text USING NULL"
    execute "ALTER TABLE users ALTER COLUMN provider_refresh_token TYPE text USING NULL"
  end
end
