defmodule Dialectic.Repo.Migrations.AddSitemapIndex do
  use Ecto.Migration

  def change do
    # Composite index covering the sitemap query:
    # WHERE is_published = true AND is_public = true ORDER BY updated_at DESC
    create_if_not_exists index(:graphs, [:is_published, :is_public, :updated_at])
  end
end
