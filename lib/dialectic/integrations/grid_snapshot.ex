defmodule Dialectic.Integrations.GridSnapshot do
  use Ecto.Schema

  schema "mcp_grid_snapshots" do
    field :graph_title, :string
    field :revision, :integer
    field :data, :map
    timestamps(type: :utc_datetime)
  end
end
