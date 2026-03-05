defmodule Dialectic.Repo.Migrations.AddProfileFieldsToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :username, :citext
      add :bio, :string, size: 500
      add :gravatar_id, :string, size: 100
      add :theme, :string, default: "default"
    end

    # Backfill existing users with a username derived from their email.
    # Uses the local part (before @), lowercased, stripped of non-alphanumeric
    # chars (except hyphens). A window function detects collisions and appends
    # a numeric suffix (-2, -3, …) when the same base username appears more
    # than once.
    execute(
      """
      WITH base_usernames AS (
        SELECT
          id,
          regexp_replace(
            regexp_replace(
              regexp_replace(
                lower(split_part(email, '@', 1)),
                '[^a-z0-9-]', '', 'g'
              ),
              '-+', '-', 'g'
            ),
            '^-|-$', '', 'g'
          ) AS base_name
        FROM users
        WHERE username IS NULL
      ),
      numbered AS (
        SELECT
          id,
          CASE WHEN base_name = '' THEN 'user' ELSE left(base_name, 30) END AS base_name,
          row_number() OVER (
            PARTITION BY CASE WHEN base_name = '' THEN 'user' ELSE left(base_name, 30) END
            ORDER BY id
          ) AS rn
        FROM base_usernames
      )
      UPDATE users
      SET username = CASE
        WHEN numbered.rn = 1 THEN numbered.base_name
        ELSE left(numbered.base_name, 25) || '-' || numbered.rn::text
      END
      FROM numbered
      WHERE users.id = numbered.id
      """,
      # Down migration: clear all usernames (the column will be dropped anyway)
      "UPDATE users SET username = NULL"
    )

    create unique_index(:users, [:username])
  end
end
