defmodule Dialectic.Repo.Migrations.RemoveSocialLinksFromUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      remove :website_url, :string, size: 255
      remove :twitter_handle, :string, size: 100
      remove :linkedin_url, :string, size: 255
    end
  end
end
