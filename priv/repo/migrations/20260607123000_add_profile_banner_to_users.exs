defmodule Dialectic.Repo.Migrations.AddProfileBannerToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :profile_banner, :string, size: 100
    end
  end
end
