defmodule Dialectic.Repo.Migrations.AddMcpAuthorizations do
  use Ecto.Migration

  def change do
    create table(:mcp_authorizations) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :client_id, :string, null: false
      add :redirect_uri, :text, null: false
      add :resource, :text, null: false
      add :scope, :string, null: false
      add :code_challenge, :string, null: false
      add :code_hash, :binary
      add :code_expires_at, :utc_datetime, null: false
      add :token_hash, :binary
      add :token_expires_at, :utc_datetime
      add :revoked_at, :utc_datetime
      timestamps(type: :utc_datetime)
    end

    create unique_index(:mcp_authorizations, [:code_hash])
    create unique_index(:mcp_authorizations, [:token_hash])
    create index(:mcp_authorizations, [:user_id])

    create table(:mcp_grid_requests) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :request_id, :uuid, null: false
      add :payload_hash, :binary, null: false
      add :graph_title, references(:graphs, column: :title, type: :string, on_delete: :nilify_all)
      timestamps(type: :utc_datetime)
    end

    create unique_index(:mcp_grid_requests, [:user_id, :request_id])
  end
end
