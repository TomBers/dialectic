defmodule Dialectic.Repo.Migrations.AddBannerPathToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :banner_path, :string, size: 500
    end
  end
end
