defmodule Dialectic.Integrations.Exploration do
  use Ecto.Schema

  schema "mcp_explorations" do
    belongs_to :user, Dialectic.Accounts.User
    field :request_id, Ecto.UUID
    field :graph_title, :string
    field :stage, :string, default: "opening"
    field :steps, :map, default: %{}
    field :coordinator_job_id, :integer
    field :error, :string
    field :completed_revision, :integer
    timestamps(type: :utc_datetime)
  end
end
