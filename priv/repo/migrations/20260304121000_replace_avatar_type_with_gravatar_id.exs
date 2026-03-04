defmodule Dialectic.Repo.Migrations.ReplaceAvatarTypeWithGravatarId do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :gravatar_id, :string, size: 100
      add :avatar_url, :string, size: 500
      remove :avatar_type, :string, default: "default"
    end
  end
end
