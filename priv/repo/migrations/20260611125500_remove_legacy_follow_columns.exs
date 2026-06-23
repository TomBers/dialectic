defmodule Dialectic.Repo.Migrations.RemoveLegacyFollowColumns do
  use Ecto.Migration

  def change do
    alter table(:follows) do
      remove_if_exists :follower_id, references(:users)
      remove_if_exists :followed_id, references(:users)
    end
  end
end
