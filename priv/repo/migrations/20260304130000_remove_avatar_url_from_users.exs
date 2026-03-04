defmodule Dialectic.Repo.Migrations.RemoveAvatarUrlFromUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      remove :avatar_url, :string, size: 500
    end
  end
end
