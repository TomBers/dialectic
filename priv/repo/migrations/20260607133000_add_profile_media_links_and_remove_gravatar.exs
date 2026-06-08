defmodule Dialectic.Repo.Migrations.AddProfileMediaLinksAndRemoveGravatar do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :avatar_path, :text
      add :banner_path, :text
      add :profile_banner, :string
      add :profile_links, :map, null: false, default: %{"links" => []}

      remove :gravatar_id
    end
  end
end
