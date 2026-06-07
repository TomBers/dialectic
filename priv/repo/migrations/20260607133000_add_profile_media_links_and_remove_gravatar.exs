defmodule Dialectic.Repo.Migrations.AddProfileMediaLinksAndRemoveGravatar do
  use Ecto.Migration

  def up do
    execute("ALTER TABLE users ADD COLUMN IF NOT EXISTS avatar_path varchar(500)")
    execute("ALTER TABLE users ADD COLUMN IF NOT EXISTS banner_path varchar(500)")
    execute("ALTER TABLE users ADD COLUMN IF NOT EXISTS profile_banner varchar(100)")

    execute("""
    ALTER TABLE users
    ADD COLUMN IF NOT EXISTS profile_links jsonb NOT NULL DEFAULT '{"links": []}'::jsonb
    """)

    execute("ALTER TABLE users DROP COLUMN IF EXISTS gravatar_id")
  end

  def down do
    execute("ALTER TABLE users ADD COLUMN IF NOT EXISTS gravatar_id varchar(100)")
    execute("ALTER TABLE users DROP COLUMN IF EXISTS profile_links")
    execute("ALTER TABLE users DROP COLUMN IF EXISTS profile_banner")
    execute("ALTER TABLE users DROP COLUMN IF EXISTS banner_path")
    execute("ALTER TABLE users DROP COLUMN IF EXISTS avatar_path")
  end
end
