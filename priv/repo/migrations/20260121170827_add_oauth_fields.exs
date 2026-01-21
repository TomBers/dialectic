defmodule Dialectic.Repo.Migrations.AddOauthFields do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add_if_not_exists :provider, :string
      add_if_not_exists :provider_id, :string
      add_if_not_exists :access_token, :text
    end

    execute(
      "CREATE UNIQUE INDEX IF NOT EXISTS users_provider_provider_id_index ON users (provider, provider_id)",
      "DROP INDEX IF EXISTS users_provider_provider_id_index"
    )

    execute(
      "ALTER TABLE users ALTER COLUMN hashed_password DROP NOT NULL",
      "ALTER TABLE users ALTER COLUMN hashed_password SET NOT NULL"
    )
  end
end
