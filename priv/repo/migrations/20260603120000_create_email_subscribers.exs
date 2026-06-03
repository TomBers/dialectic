defmodule Dialectic.Repo.Migrations.CreateEmailSubscribers do
  use Ecto.Migration

  def change do
    create table(:email_subscribers) do
      add :email, :citext, null: false
      add :source, :string
      add :confirmed_at, :utc_datetime
      add :unsubscribed_at, :utc_datetime
      add :confirmation_token, :binary
      add :unsubscribe_token, :binary, null: false
      add :user_id, references(:users, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create unique_index(:email_subscribers, [:email])
    create index(:email_subscribers, [:user_id])
    create unique_index(:email_subscribers, [:confirmation_token])
    create unique_index(:email_subscribers, [:unsubscribe_token])
  end
end
