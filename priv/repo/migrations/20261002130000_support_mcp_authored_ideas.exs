defmodule Dialectic.Repo.Migrations.SupportMcpAuthoredIdeas do
  use Ecto.Migration

  def change do
    alter table(:mcp_grid_actions) do
      modify :job_id, :bigint, null: true, from: {:bigint, null: false}
      add :content_hash, :binary
    end
  end
end
