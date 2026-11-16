defmodule Dialectic.Repo.Migrations.AllowNodeFreeOperationReceipts do
  use Ecto.Migration

  def change do
    alter table(:mcp_grid_actions) do
      modify :parent_node_id, :string, null: true, from: {:string, null: false}
      modify :node_id, :string, null: true, from: {:string, null: false}
    end
  end
end
