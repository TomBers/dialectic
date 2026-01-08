defmodule Mix.Tasks.BackfillGraphSlugs do
  @moduledoc """
  Backfills slugs for existing graphs that don't have one.

  ## Usage

      mix backfill_graph_slugs

  This task will:
  - Find all graphs without a slug
  - Generate a unique slug for each
  - Update the database record

  It's safe to run multiple times - it only updates graphs without slugs.
  """
  use Mix.Task

  alias Dialectic.Repo
  alias Dialectic.Accounts.Graph
  alias Dialectic.DbActions.Graphs

  import Ecto.Query

  @shortdoc "Backfills slugs for existing graphs"

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    IO.puts("Starting graph slug backfill...")

    # Find all graphs without a slug
    graphs_without_slug =
      from(g in Graph, where: is_nil(g.slug) or g.slug == "")
      |> Repo.all()

    total = length(graphs_without_slug)

    if total == 0 do
      IO.puts("✓ All graphs already have slugs!")
      :ok
    else
      IO.puts("Found #{total} graphs without slugs. Generating...")

      results =
        graphs_without_slug
        |> Enum.with_index(1)
        |> Enum.map(fn {graph, index} ->
          slug = Graphs.generate_unique_slug(graph.title)

          case graph
               |> Graph.changeset(%{slug: slug})
               |> Repo.update() do
            {:ok, updated_graph} ->
              IO.puts(
                "[#{index}/#{total}] ✓ Generated slug '#{updated_graph.slug}' for '#{String.slice(graph.title, 0..50)}'"
              )

              :ok

            {:error, changeset} ->
              IO.puts(
                "[#{index}/#{total}] ✗ Failed to generate slug for '#{String.slice(graph.title, 0..50)}': #{inspect(changeset.errors)}"
              )

              :error
          end
        end)

      success_count = Enum.count(results, &(&1 == :ok))
      error_count = Enum.count(results, &(&1 == :error))

      IO.puts("\n" <> String.duplicate("=", 50))
      IO.puts("Backfill complete!")
      IO.puts("✓ Success: #{success_count}")

      if error_count > 0 do
        IO.puts("✗ Errors: #{error_count}")
      end

      IO.puts(String.duplicate("=", 50))
    end
  end
end
