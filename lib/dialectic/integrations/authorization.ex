defmodule Dialectic.Integrations.Authorization do
  use Ecto.Schema

  schema "mcp_authorizations" do
    belongs_to :user, Dialectic.Accounts.User
    field :client_id, :string
    field :redirect_uri, :string
    field :resource, :string
    field :scope, :string
    field :code_challenge, :string
    field :code_hash, :binary
    field :code_expires_at, :utc_datetime
    field :token_hash, :binary
    field :token_expires_at, :utc_datetime
    field :revoked_at, :utc_datetime
    timestamps(type: :utc_datetime)
  end
end
