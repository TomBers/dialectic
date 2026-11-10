defmodule Dialectic.Repo.Migrations.AddMcpClientsAndRefreshTokens do
  use Ecto.Migration

  def change do
    create table(:mcp_clients) do
      add :client_id, :string, null: false
      add :name, :string, null: false
      add :redirect_uris, {:array, :string}, null: false
      timestamps(type: :utc_datetime)
    end

    create unique_index(:mcp_clients, [:client_id])

    create table(:mcp_refresh_tokens) do
      add :authorization_id, references(:mcp_authorizations, on_delete: :delete_all), null: false
      add :token_hash, :binary, null: false
      add :expires_at, :utc_datetime, null: false
      add :used_at, :utc_datetime
      timestamps(type: :utc_datetime)
    end

    create unique_index(:mcp_refresh_tokens, [:token_hash])
    create index(:mcp_refresh_tokens, [:authorization_id])
  end
end
