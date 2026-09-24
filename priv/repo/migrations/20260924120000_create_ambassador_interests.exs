defmodule Dialectic.Repo.Migrations.CreateAmbassadorInterests do
  use Ecto.Migration

  def change do
    create table(:ambassador_interests) do
      add :email, :string, null: false
      add :role, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:ambassador_interests, [:email])
  end
end
