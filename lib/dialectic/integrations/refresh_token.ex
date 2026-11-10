defmodule Dialectic.Integrations.RefreshToken do
  use Ecto.Schema

  schema "mcp_refresh_tokens" do
    belongs_to :authorization, Dialectic.Integrations.Authorization
    field :token_hash, :binary
    field :expires_at, :utc_datetime
    field :used_at, :utc_datetime
    timestamps(type: :utc_datetime)
  end
end
