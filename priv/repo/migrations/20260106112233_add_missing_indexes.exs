defmodule Dialectic.Repo.Migrations.AddMissingIndexes do
  use Ecto.Migration

  def change do
    # Add index on graphs.user_id for "my graphs" queries
    create_if_not_exists index(:graphs, [:user_id])

    # Add composite index for public graphs queries with sorting
    create_if_not_exists index(:graphs, [:is_public, :inserted_at])

    # Add index for filtering deleted graphs
    create_if_not_exists index(:graphs, [:is_deleted])

    # Add index for published graphs
    create_if_not_exists index(:graphs, [:is_published])

    # Add index for locked graphs
    create_if_not_exists index(:graphs, [:is_locked])

    # Add index on notes.graph_title for fetching notes by graph (if not exists)
    # This may already exist via foreign key, but ensuring it's optimized
    create_if_not_exists index(:notes, [:graph_title])

    # Add composite index for user's graphs with sorting
    create_if_not_exists index(:graphs, [:user_id, :inserted_at])

    # Add index for user's non-deleted graphs
    create_if_not_exists index(:graphs, [:user_id, :is_deleted, :inserted_at])
  end
end
