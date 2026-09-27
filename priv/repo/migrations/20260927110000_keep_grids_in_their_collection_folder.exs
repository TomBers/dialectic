defmodule Dialectic.Repo.Migrations.KeepGridsInTheirCollectionFolder do
  use Ecto.Migration

  def up do
    execute """
    WITH RECURSIVE folders AS (
      SELECT id, user_id, id AS root_id, 0 AS depth
      FROM learning_collections
      WHERE parent_id IS NULL AND origin = 'manual'
      UNION ALL
      SELECT child.id, child.user_id, parent.root_id, parent.depth + 1
      FROM learning_collections child
      JOIN folders parent ON child.parent_id = parent.id AND child.user_id = parent.user_id
      WHERE child.origin = 'manual'
    ), placements AS (
      SELECT membership.id,
        ROW_NUMBER() OVER (
          PARTITION BY folders.user_id, folders.root_id, membership.graph_title
          ORDER BY folders.depth DESC, membership.updated_at DESC, membership.id DESC
        ) AS position
      FROM learning_collection_grids membership
      JOIN folders ON folders.id = membership.collection_id
    )
    DELETE FROM learning_collection_grids membership
    USING placements
    WHERE membership.id = placements.id AND placements.position > 1
    """
  end

  def down, do: :ok
end
