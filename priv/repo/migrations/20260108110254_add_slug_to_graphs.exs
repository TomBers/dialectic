defmodule Dialectic.Repo.Migrations.AddSlugToGraphs do
  use Ecto.Migration

  def up do
    alter table(:graphs) do
      add :slug, :string
    end

    create unique_index(:graphs, [:slug])

    # Backfill slugs for existing graphs
    flush()

    # Use Elixir code to generate slugs reliably
    execute(&backfill_slugs/0)
  end

  def down do
    drop unique_index(:graphs, [:slug])

    alter table(:graphs) do
      remove :slug
    end
  end

  defp backfill_slugs do
    # Get the repo module
    repo = repo()

    # Find all graphs without slugs using raw SQL
    result = repo.query!("SELECT title FROM graphs WHERE slug IS NULL OR slug = ''")

    titles = Enum.map(result.rows, fn [title] -> title end)

    IO.puts("Backfilling slugs for #{length(titles)} graphs...")

    Enum.each(titles, fn title ->
      slug = generate_unique_slug(title, repo)

      repo.query!(
        "UPDATE graphs SET slug = $1 WHERE title = $2",
        [slug, title]
      )
    end)

    IO.puts("✓ Slug backfill complete!")
  end

  defp generate_unique_slug(title, repo) do
    base_slug = generate_slug_from_title(title)

    # Try to find a unique slug
    Enum.find_value(1..5, fn attempt ->
      slug =
        if attempt == 1 do
          base_slug
        else
          "#{base_slug}-#{:crypto.strong_rand_bytes(3) |> Base.encode16(case: :lower)}"
        end

      # Check if slug exists
      result = repo.query!("SELECT title FROM graphs WHERE slug = $1 LIMIT 1", [slug])

      if Enum.empty?(result.rows), do: slug, else: nil
    end) || "#{base_slug}-#{:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)}"
  end

  defp generate_slug_from_title(title) do
    base_slug =
      title
      |> String.downcase()
      |> String.slice(0, 50)
      |> String.replace(~r/[^a-z0-9\s-]/, "")
      |> String.replace(~r/\s+/, "-")
      |> String.replace(~r/-+/, "-")
      |> String.trim("-")

    base_slug = if base_slug == "", do: "graph", else: base_slug

    # Add a short random suffix for uniqueness
    suffix = :crypto.strong_rand_bytes(3) |> Base.encode16(case: :lower)
    "#{base_slug}-#{suffix}"
  end
end
