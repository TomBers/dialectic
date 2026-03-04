defmodule Dialectic.Repo.Migrations.RemoveDisplayNameFromUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      remove :display_name, :string, size: 100
    end
  end
end
