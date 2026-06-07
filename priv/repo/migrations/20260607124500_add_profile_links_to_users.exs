defmodule Dialectic.Repo.Migrations.AddProfileLinksToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :profile_links, :map, default: %{links: []}, null: false
    end
  end
end
