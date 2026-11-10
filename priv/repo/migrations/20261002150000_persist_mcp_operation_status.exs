defmodule Dialectic.Repo.Migrations.PersistMcpOperationStatus do
  use Ecto.Migration

  def up do
    alter table(:mcp_grid_actions) do
      add :status, :string, null: false, default: "queued"
    end

    create index(:mcp_grid_actions, [:job_id])

    create constraint(:mcp_grid_actions, :mcp_operation_status,
             check: "status IN ('queued', 'generating', 'completed', 'failed', 'unknown')"
           )

    execute("""
    UPDATE mcp_grid_actions AS operation
    SET status = CASE
      WHEN operation.job_id IS NULL THEN 'completed'
      WHEN job.state = 'completed' THEN 'completed'
      WHEN job.state IN ('cancelled', 'discarded') THEN 'failed'
      WHEN job.state = 'executing' THEN 'generating'
      WHEN job.state IN ('available', 'scheduled', 'retryable') THEN 'queued'
      ELSE 'unknown'
    END
    FROM mcp_grid_actions AS existing
    LEFT JOIN oban_jobs AS job ON job.id = existing.job_id
    WHERE operation.id = existing.id
    """)

    execute("""
    CREATE FUNCTION sync_mcp_operation_status() RETURNS trigger AS $$
    DECLARE
      job_state text;
      operation_status text;
    BEGIN
      IF TG_OP = 'DELETE' THEN
        job_state := OLD.state::text;
      ELSE
        job_state := NEW.state::text;
      END IF;

      operation_status := CASE
        WHEN job_state = 'completed' THEN 'completed'
        WHEN job_state IN ('cancelled', 'discarded') THEN 'failed'
        WHEN TG_OP = 'DELETE' THEN 'unknown'
        WHEN job_state = 'executing' THEN 'generating'
        ELSE 'queued'
      END;

      UPDATE mcp_grid_actions
      SET status = operation_status, updated_at = timezone('UTC', now())
      WHERE job_id = OLD.id AND status IS DISTINCT FROM operation_status;
      RETURN NULL;
    END;
    $$ LANGUAGE plpgsql;
    """)

    execute("""
    CREATE TRIGGER sync_mcp_operation_status
    AFTER UPDATE OF state OR DELETE ON oban_jobs
    FOR EACH ROW EXECUTE FUNCTION sync_mcp_operation_status()
    """)
  end

  def down do
    execute("DROP TRIGGER sync_mcp_operation_status ON oban_jobs")
    execute("DROP FUNCTION sync_mcp_operation_status()")
    drop constraint(:mcp_grid_actions, :mcp_operation_status)
    drop index(:mcp_grid_actions, [:job_id])

    alter table(:mcp_grid_actions) do
      remove :status
    end
  end
end
