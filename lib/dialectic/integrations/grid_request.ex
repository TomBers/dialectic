defmodule Dialectic.Integrations.GridRequest do
  use Ecto.Schema

  schema "mcp_grid_requests" do
    belongs_to :user, Dialectic.Accounts.User
    field :request_id, Ecto.UUID
    field :payload_hash, :binary
    field :graph_title, :string
    timestamps(type: :utc_datetime)
  end
end
