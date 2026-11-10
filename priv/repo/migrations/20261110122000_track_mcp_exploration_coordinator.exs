defmodule Dialectic.Repo.Migrations.TrackMcpExplorationCoordinator do
  use Ecto.Migration

  def change do
    alter table(:mcp_explorations) do
      add :coordinator_job_id, :bigint
    end
  end
end
