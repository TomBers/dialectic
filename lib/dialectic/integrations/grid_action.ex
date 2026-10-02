defmodule Dialectic.Integrations.GridAction do
  use Ecto.Schema

  schema "mcp_grid_actions" do
    belongs_to :user, Dialectic.Accounts.User
    field :request_id, Ecto.UUID
    field :graph_title, :string
    field :parent_node_id, :string
    field :action, :string
    field :node_id, :string
    field :answer_node_id, :string
    field :job_id, :integer
    field :content_hash, :binary
    field :status, :string, default: "queued"
    timestamps(type: :utc_datetime)
  end
end
