#!/usr/bin/env elixir

# Script to verify the Popper graph was created successfully
# Run with: mix run priv/repo/verify_popper.exs

alias Dialectic.Repo
alias Dialectic.Accounts.Graph
import Ecto.Query

IO.puts("Checking for Popper graph...\n")

query = from g in Graph,
  where: ilike(g.title, "%Popper%"),
  select: %{
    title: g.title,
    slug: g.slug,
    tags: g.tags,
    is_public: g.is_public,
    is_published: g.is_published,
    node_count: fragment("jsonb_array_length(?->'nodes')", g.data),
    edge_count: fragment("jsonb_array_length(?->'edges')", g.data)
  }

case Repo.all(query) do
  [] ->
    IO.puts("❌ No Popper graphs found in database")

  graphs ->
    IO.puts("✓ Found #{length(graphs)} Popper graph(s):\n")

    Enum.each(graphs, fn graph ->
      IO.puts("Title: #{graph.title}")
      IO.puts("Slug: #{graph.slug}")
      IO.puts("Tags: #{inspect(graph.tags)}")
      IO.puts("Public: #{graph.is_public}")
      IO.puts("Published: #{graph.is_published}")
      IO.puts("Nodes: #{graph.node_count}")
      IO.puts("Edges: #{graph.edge_count}")
      IO.puts("\nAccess via:")
      IO.puts("  - http://localhost:4000/graph/#{graph.slug}")
      IO.puts("  - Or search for 'Popper' in the graphs list")
      IO.puts("\n#{String.duplicate("=", 60)}\n")
    end)
end
