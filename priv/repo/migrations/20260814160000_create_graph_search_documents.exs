defmodule Dialectic.Repo.Migrations.CreateGraphSearchDocuments do
  use Ecto.Migration

  def up do
    execute("CREATE EXTENSION IF NOT EXISTS pg_trgm")

    create table(:graph_search_documents) do
      add :graph_title,
          references(:graphs,
            column: :title,
            type: :string,
            on_delete: :delete_all,
            on_update: :update_all
          ),
          null: false

      add :kind, :string, null: false
      add :node_id, :string
      add :content, :text, null: false, default: ""
      add :source_text, :text, null: false, default: ""
      add :search_text, :text, null: false, default: ""
    end

    create constraint(:graph_search_documents, :graph_search_documents_kind_check,
             check: "kind IN ('graph', 'node')"
           )

    create index(:graph_search_documents, [:graph_title])

    create unique_index(:graph_search_documents, [:graph_title],
             where: "kind = 'graph'",
             name: :graph_search_documents_graph_unique_index
           )

    create unique_index(:graph_search_documents, [:graph_title, :node_id],
             where: "kind = 'node'",
             name: :graph_search_documents_node_unique_index
           )

    execute("""
    CREATE INDEX graph_search_documents_search_text_trgm_index
    ON graph_search_documents
    USING gin (search_text gin_trgm_ops)
    """)

    execute(sync_function_sql())

    execute("""
    CREATE TRIGGER sync_graph_search_documents_trigger
    AFTER INSERT OR UPDATE OF data, title, tags, is_public, is_published, is_deleted OR DELETE
    ON graphs
    FOR EACH ROW
    EXECUTE FUNCTION sync_graph_search_documents()
    """)

    execute("""
    INSERT INTO graph_search_documents
      (graph_title, kind, node_id, content, source_text, search_text)
    SELECT
      graph.title,
      'graph',
      NULL,
      '',
      '',
      concat_ws(' ', graph.title, array_to_string(COALESCE(graph.tags, ARRAY[]::varchar[]), ' '))
    FROM graphs AS graph
    WHERE graph.is_public = true
      AND graph.is_published = true
      AND COALESCE(graph.is_deleted, false) = false
    """)

    execute("""
    INSERT INTO graph_search_documents
      (graph_title, kind, node_id, content, source_text, search_text)
    SELECT
      graph.title,
      'node',
      node.value->>'id',
      COALESCE(node.value->>'content', ''),
      COALESCE(node.value->>'source_text', ''),
      concat_ws(' ', node.value->>'content', node.value->>'source_text')
    FROM graphs AS graph
    CROSS JOIN LATERAL jsonb_array_elements(
      CASE
        WHEN jsonb_typeof(graph.data->'nodes') = 'array' THEN graph.data->'nodes'
        ELSE '[]'::jsonb
      END
    ) AS node(value)
    WHERE graph.is_public = true
      AND graph.is_published = true
      AND COALESCE(graph.is_deleted, false) = false
      AND node.value->>'id' IS NOT NULL
      AND COALESCE(node.value->>'deleted', 'false') <> 'true'
      AND concat_ws(' ', node.value->>'content', node.value->>'source_text') <> ''
    ON CONFLICT DO NOTHING
    """)

    execute("ANALYZE graph_search_documents")
  end

  def down do
    execute("DROP TRIGGER IF EXISTS sync_graph_search_documents_trigger ON graphs")
    execute("DROP FUNCTION IF EXISTS sync_graph_search_documents()")
    drop table(:graph_search_documents)
  end

  defp sync_function_sql do
    """
    CREATE OR REPLACE FUNCTION sync_graph_search_documents()
    RETURNS trigger
    LANGUAGE plpgsql
    AS $$
    BEGIN
      IF TG_OP = 'DELETE' THEN
        DELETE FROM graph_search_documents WHERE graph_title = OLD.title;
        RETURN OLD;
      END IF;

      IF TG_OP = 'UPDATE' AND OLD.title IS DISTINCT FROM NEW.title THEN
        DELETE FROM graph_search_documents WHERE graph_title = OLD.title;
      END IF;

      DELETE FROM graph_search_documents WHERE graph_title = NEW.title;

      IF NEW.is_public = true
         AND NEW.is_published = true
         AND COALESCE(NEW.is_deleted, false) = false THEN
        INSERT INTO graph_search_documents
          (graph_title, kind, node_id, content, source_text, search_text)
        VALUES
          (
            NEW.title,
            'graph',
            NULL,
            '',
            '',
            concat_ws(' ', NEW.title, array_to_string(COALESCE(NEW.tags, ARRAY[]::varchar[]), ' '))
          );

        INSERT INTO graph_search_documents
          (graph_title, kind, node_id, content, source_text, search_text)
        SELECT
          NEW.title,
          'node',
          node.value->>'id',
          COALESCE(node.value->>'content', ''),
          COALESCE(node.value->>'source_text', ''),
          concat_ws(' ', node.value->>'content', node.value->>'source_text')
        FROM jsonb_array_elements(
          CASE
            WHEN jsonb_typeof(NEW.data->'nodes') = 'array' THEN NEW.data->'nodes'
            ELSE '[]'::jsonb
          END
        ) AS node(value)
        WHERE node.value->>'id' IS NOT NULL
          AND COALESCE(node.value->>'deleted', 'false') <> 'true'
          AND concat_ws(' ', node.value->>'content', node.value->>'source_text') <> ''
        ON CONFLICT DO NOTHING;
      END IF;

      RETURN NEW;
    END;
    $$
    """
  end
end
