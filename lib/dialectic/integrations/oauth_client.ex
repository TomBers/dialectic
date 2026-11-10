defmodule Dialectic.Integrations.OAuthClient do
  use Ecto.Schema

  schema "mcp_clients" do
    field :client_id, :string
    field :name, :string
    field :redirect_uris, {:array, :string}
    timestamps(type: :utc_datetime)
  end
end
