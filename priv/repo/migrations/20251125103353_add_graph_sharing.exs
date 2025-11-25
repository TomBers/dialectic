defmodule Dialectic.Repo.Migrations.AddGraphSharing do
  use Ecto.Migration

  def change do
    alter table(:graphs) do
      add :share_token, :string
    end

    create unique_index(:graphs, [:share_token])

    create table(:graph_shares) do
      add :graph_title, references(:graphs, column: :title, type: :string, on_delete: :delete_all)
      add :email, :string, null: false
      add :permission, :string, default: "edit", null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:graph_shares, [:graph_title, :email])
    create index(:graph_shares, [:email])
  end
end
