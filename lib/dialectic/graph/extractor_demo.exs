#!/usr/bin/env elixir

# Demo script for Dialectic.Graph.Extractor
#
# This script demonstrates how to extract graphs from the database
# into a concise format suitable for image generation tools.
#
# Run in IEx console:
#   iex> Code.eval_file("lib/dialectic/graph/extractor_demo.exs")
#
# Or run as a script:
#   mix run lib/dialectic/graph/extractor_demo.exs

alias Dialectic.Graph.Extractor
alias Dialectic.DbActions.Graphs

IO.puts("\n" <> String.duplicate("=", 80))
IO.puts("GRAPH EXTRACTOR DEMO")
IO.puts(String.duplicate("=", 80) <> "\n")

# Example 1: Create a sample graph for demonstration
IO.puts("Example 1: Creating a sample graph for demonstration")
IO.puts(String.duplicate("-", 80))

sample_data = %{
  "nodes" => [
    %{
      "id" => "1",
      "content" => "What is consciousness?",
      "class" => "question",
      "deleted" => false
    },
    %{
      "id" => "2",
      "content" => "Consciousness is the state of being aware of one's surroundings",
      "class" => "answer",
      "deleted" => false
    },
    %{
      "id" => "3",
      "content" => "Consciousness is physical - emerges from neural activity",
      "class" => "thesis",
      "deleted" => false
    },
    %{
      "id" => "4",
      "content" => "Consciousness is non-physical - cannot be reduced to matter",
      "class" => "antithesis",
      "deleted" => false
    },
    %{
      "id" => "group-1",
      "content" => "",
      "class" => "",
      "compound" => true,
      "deleted" => false
    },
    %{
      "id" => "5",
      "content" => "Consciousness may be an emergent property that transcends simple reduction",
      "class" => "synthesis",
      "parent" => "group-1",
      "deleted" => false
    }
  ],
  "edges" => [
    %{"data" => %{"source" => "1", "target" => "2"}},
    %{"data" => %{"source" => "2", "target" => "3"}},
    %{"data" => %{"source" => "2", "target" => "4"}},
    %{"data" => %{"source" => "3", "target" => "5"}},
    %{"data" => %{"source" => "4", "target" => "5"}}
  ]
}

graph = %Dialectic.Accounts.Graph{
  title: "Demo Graph",
  data: sample_data
}

IO.puts("Sample graph created with #{length(sample_data["nodes"])} nodes\n")

# Example 2: Extract the graph
IO.puts("Example 2: Extracting graph to concise format")
IO.puts(String.duplicate("-", 80))

extracted = Extractor.extract_for_image_generation(graph)

IO.puts("Extracted #{length(extracted.nodes)} nodes and #{length(extracted.edges)} edges")
IO.puts("\nExtracted structure:")
IO.inspect(extracted, pretty: true, limit: :infinity)
IO.puts("")

# Example 3: Extract to JSON (pretty-printed)
IO.puts("Example 3: Extract to pretty JSON")
IO.puts(String.duplicate("-", 80))

json_output = Extractor.extract_to_json(graph)
IO.puts(json_output)
IO.puts("")

# Example 4: Extract to compact JSON
IO.puts("Example 4: Extract to compact JSON (for API/tool usage)")
IO.puts(String.duplicate("-", 80))

compact_json = Extractor.extract_to_compact_json(graph)
IO.puts("Compact JSON (#{String.length(compact_json)} characters):")
IO.puts(String.slice(compact_json, 0, 200) <> "...")
IO.puts("")

# Example 5: Show what gets filtered out
IO.puts("Example 5: Demonstrating filtering")
IO.puts(String.duplicate("-", 80))

IO.puts("The extractor automatically filters out:")
IO.puts("  ✓ Deleted nodes (deleted: true)")
IO.puts("  ✓ User information")
IO.puts("  ✓ Note metadata (noted_by)")
IO.puts("  ✓ Timestamps")
IO.puts("  ✓ Source text references")
IO.puts("  ✓ Edges pointing to deleted/non-existent nodes")
IO.puts("")

# Example 6: Using with a real graph from the database
IO.puts("Example 6: Using with a real graph from the database")
IO.puts(String.duplicate("-", 80))

IO.puts("To extract a real graph from your database:")
IO.puts("")
IO.puts("  # By title")
IO.puts("  {:ok, data} = Extractor.extract_for_image_generation(\"My Graph Title\")")
IO.puts("")
IO.puts("  # By slug")
IO.puts("  {:ok, data} = Extractor.extract_for_image_generation(\"my-graph-slug-abc123\")")
IO.puts("")
IO.puts("  # Get as JSON for image generation tool")
IO.puts("  {:ok, json} = Extractor.extract_to_json(\"My Graph Title\")")
IO.puts("  File.write!(\"graph_for_image.json\", json)")
IO.puts("")

# Example 7: Integration with image generation tools
IO.puts("Example 7: Next steps - Using with image generation")
IO.puts(String.duplicate("-", 80))

IO.puts("The extracted JSON can be passed to image generation tools:")
IO.puts("")
IO.puts("  # Save to file for external tool")
IO.puts("  {:ok, json} = Extractor.extract_to_json(\"My Graph\")")
IO.puts("  File.write!(\"graph.json\", json)")
IO.puts("")
IO.puts("  # Or use directly with an API")
IO.puts("  {:ok, compact} = Extractor.extract_to_compact_json(\"My Graph\")")
IO.puts("  HTTPoison.post(\"https://api.image-gen.com/graph\", compact, headers)")
IO.puts("")
IO.puts("  # Or integrate with a LiveView")
IO.puts("  def handle_event(\"export_image\", %{\"title\" => title}, socket) do")
IO.puts("    {:ok, json} = Extractor.extract_to_compact_json(title)")
IO.puts("    # Send to image generation service...")
IO.puts("    {:noreply, socket}")
IO.puts("  end")
IO.puts("")

# Example 8: Output format reference
IO.puts("Example 8: Output format reference")
IO.puts(String.duplicate("-", 80))

IO.puts("Node structure:")
IO.puts("  %{")
IO.puts("    id: \"unique-id\",           # Node identifier")
IO.puts("    content: \"Node text\",       # Main content")
IO.puts("    class: \"question\",          # Node type (question, answer, thesis, etc.)")
IO.puts("    parent: \"group-id\",         # Optional: parent group ID")
IO.puts("    compound: true              # Optional: marks group nodes")
IO.puts("  }")
IO.puts("")
IO.puts("Edge structure:")
IO.puts("  %{")
IO.puts("    from: \"source-id\",          # Source node ID")
IO.puts("    to: \"target-id\"             # Target node ID")
IO.puts("  }")
IO.puts("")

IO.puts(String.duplicate("=", 80))
IO.puts("DEMO COMPLETE")
IO.puts(String.duplicate("=", 80) <> "\n")
