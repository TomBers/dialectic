defmodule Dialectic.Repo.Migrations.AddAvatarPathToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :avatar_path, :string, size: 500
    end
  end
end
