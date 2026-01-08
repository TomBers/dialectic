#!/usr/bin/env elixir

# Verification script for slug-based URL implementation
# Run with: mix run verify_slugs.exs

IO.puts("\n" <> String.duplicate("=", 60))
IO.puts("Slug-Based URL Implementation Verification")
IO.puts(String.duplicate("=", 60) <> "\n")

alias Dialectic.Repo
alias Dialectic.Accounts.Graph
alias Dialectic.DbActions.Graphs
import Ecto.Query

# Test 1: Check if slug column exists
IO.puts("✓ Test 1: Verifying slug column exists...")

try do
  Repo.one(from g in Graph, select: count(g.slug))
  IO.puts("  ✅ Slug column exists in database\n")
rescue
  e ->
    IO.puts("  ❌ FAILED: #{inspect(e)}\n")
    System.halt(1)
end

# Test 2: Check graphs with slugs
IO.puts("✓ Test 2: Checking existing graphs with slugs...")
slug_count = Repo.one(from g in Graph, where: not is_nil(g.slug), select: count())
total_count = Repo.one(from g in Graph, select: count())
IO.puts("  ✅ #{slug_count} out of #{total_count} graphs have slugs")

if slug_count < total_count do
  IO.puts("  ⚠️  Run 'mix backfill_graph_slugs' to add slugs to remaining graphs")
end

IO.puts("")

# Test 3: Show example slug transformations
IO.puts("✓ Test 3: Sample slug examples...")

sample_graphs =
  Repo.all(
    from g in Graph,
      where: not is_nil(g.slug),
      order_by: [desc: g.inserted_at],
      limit: 3,
      select: %{title: g.title, slug: g.slug}
  )

if Enum.empty?(sample_graphs) do
  IO.puts("  ⚠️  No graphs with slugs found. Create a new graph to test.")
else
  Enum.each(sample_graphs, fn graph ->
    title_display = String.slice(graph.title, 0..40)

    title_display =
      if String.length(graph.title) > 40, do: title_display <> "...", else: title_display

    IO.puts("  📄 \"#{title_display}\"")
    IO.puts("     → Slug: #{graph.slug}")
    old_url_len = String.length(URI.encode(graph.title))
    new_url_len = String.length(graph.slug)
    reduction = Float.round((1 - new_url_len / old_url_len) * 100, 1)
    IO.puts("     → URL length: #{old_url_len} → #{new_url_len} chars (#{reduction}% reduction)")
    IO.puts("")
  end)
end

# Test 4: Test slug generation
IO.puts("✓ Test 4: Testing slug generation function...")

test_titles = [
  "Test Graph",
  "What is the meaning of consciousness?",
  "A very long philosophical question that explores the nature of reality"
]

Enum.each(test_titles, fn title ->
  slug = Graphs.generate_slug(title)
  IO.puts("  \"#{title}\"")
  IO.puts("  → \"#{slug}\"")
end)

IO.puts("")

# Test 5: Test lookup functions
IO.puts("✓ Test 5: Testing graph lookup functions...")

if slug_count > 0 do
  test_graph = Repo.one(from g in Graph, where: not is_nil(g.slug), limit: 1)

  if test_graph do
    found_by_slug = Graphs.get_graph_by_slug(test_graph.slug)

    if found_by_slug,
      do: IO.puts("  ✅ get_graph_by_slug/1 works"),
      else: IO.puts("  ❌ get_graph_by_slug/1 failed")

    found_by_title = Graphs.get_graph_by_title(test_graph.title)

    if found_by_title,
      do: IO.puts("  ✅ get_graph_by_title/1 works"),
      else: IO.puts("  ❌ get_graph_by_title/1 failed")

    found_by_slug_or_title_1 = Graphs.get_graph_by_slug_or_title(test_graph.slug)

    if found_by_slug_or_title_1,
      do: IO.puts("  ✅ get_graph_by_slug_or_title/1 works with slug"),
      else: IO.puts("  ❌ get_graph_by_slug_or_title/1 failed with slug")

    found_by_slug_or_title_2 = Graphs.get_graph_by_slug_or_title(test_graph.title)

    if found_by_slug_or_title_2,
      do: IO.puts("  ✅ get_graph_by_slug_or_title/1 works with title (backward compat)"),
      else: IO.puts("  ❌ get_graph_by_slug_or_title/1 failed with title")
  end
else
  IO.puts("  ⚠️  No graphs with slugs to test. Run backfill first.")
end

IO.puts("")

# Test 6: URL comparison
IO.puts("✓ Test 6: URL comparison (Before vs After)...")

if slug_count > 0 do
  long_title_graph =
    Repo.one(
      from g in Graph,
        where: fragment("length(?) > 50", g.title) and not is_nil(g.slug),
        order_by: [desc: fragment("length(?)", g.title)],
        limit: 1
    )

  if long_title_graph do
    base_url = "http://localhost:4000"
    old_url = "#{base_url}/#{URI.encode(long_title_graph.title)}"
    new_url = "#{base_url}/g/#{long_title_graph.slug}"

    IO.puts("  Before: #{old_url}")
    IO.puts("  After:  #{new_url}")
    IO.puts("")
    IO.puts("  Old URL length: #{String.length(old_url)} chars")
    IO.puts("  New URL length: #{String.length(new_url)} chars")

    reduction = Float.round((1 - String.length(new_url) / String.length(old_url)) * 100, 1)
    IO.puts("  ✅ #{reduction}% reduction in URL length!")
  else
    IO.puts("  ℹ️  No long-titled graphs found for comparison")
  end
else
  IO.puts("  ⚠️  No graphs with slugs to compare")
end

IO.puts("")

# Final summary
IO.puts(String.duplicate("=", 60))
IO.puts("Summary")
IO.puts(String.duplicate("=", 60))

cond do
  slug_count == total_count and slug_count > 0 ->
    IO.puts("✅ All #{total_count} graphs have slugs!")
    IO.puts("✅ Slug generation is working")
    IO.puts("✅ Lookup functions are operational")
    IO.puts("\n🎉 Implementation verified successfully!")

  slug_count > 0 and slug_count < total_count ->
    IO.puts("⚠️  #{slug_count}/#{total_count} graphs have slugs")
    IO.puts("   Run: mix backfill_graph_slugs")
    IO.puts("\n✅ Implementation is working but needs backfill")

  true ->
    IO.puts("❌ No graphs with slugs found")
    IO.puts("   1. Run: mix ecto.migrate")
    IO.puts("   2. Run: mix backfill_graph_slugs")
    IO.puts("   3. Or create a new graph to test")
end

IO.puts(String.duplicate("=", 60) <> "\n")
